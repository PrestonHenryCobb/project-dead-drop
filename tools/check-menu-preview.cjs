// Browser-level checks for the menu design preview; never uses the user's browser profile.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium } = require(process.argv[2] || 'playwright');
(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  try {
    const page = await browser.newPage();
    const problems = [];
    page.on('pageerror', error => problems.push(error.message));
    const source = fs.readFileSync(path.join(__dirname, '../docs/mockups/main-menu-review.html'), 'utf8');
    const expected = {Play:'Blend in.',Agents:'Choose your cover story.',Assets:'Find your advantage',Dossiers:'Your next assignment', 'Black Market':'Make an entrance.',Profile:'Your career'};
    for (const width of [1024,736,360,320]) {
      await page.setViewportSize({ width, height: 1100 });
      await page.setContent(source);
      for (const variant of ['desk','rail']) {
        await page.evaluate(layout => document.querySelectorAll('[data-variant]').forEach(section => { section.hidden=section.firstElementChild.dataset.layout!==layout; }), variant);
        const app = page.locator(`[data-layout="${variant}"]`);
        for (const [tab,text] of Object.entries(expected)) {
          await app.locator('.cs-nav').getByRole('button',{name:tab,exact:true}).click();
          assert((await app.locator('main').innerText()).includes(text),`${variant} ${width}: ${tab} did not update`);
          const overflow = await page.evaluate(() => document.documentElement.scrollWidth>window.innerWidth);
          assert(!overflow,`${variant} ${width}: horizontal overflow in ${tab}`);
        }
        await app.getByRole('button',{name:'Play',exact:true}).click();
        await app.getByRole('button',{name:'Solos',exact:true}).click();
        assert.equal(await app.getByRole('button',{name:'Solos',exact:true}).getAttribute('aria-pressed'),'true');
        await app.getByRole('button',{name:'Review loadout →',exact:true}).click();
        await app.locator('[data-agent="Lattice"]').click();
        assert.equal(await page.evaluate(()=>document.activeElement.dataset.agent),'Lattice','Selection lost keyboard focus');
        await app.getByRole('button',{name:'Play',exact:true}).click();
        assert((await app.locator('.cs-mark').innerText()).includes('LATTICE'));
        await app.locator('[data-mint]').click();
        assert((await app.locator('main').innerText()).toLowerCase().includes('the mint'));
        await app.getByRole('button',{name:'Back to Black Market',exact:true}).click();
        assert((await app.locator('main').innerText()).includes('Make an entrance.'));
      }
    }
    await page.setContent('<script>window.savedCalls=[];window.openai={widgetState:{modelContent:{menu:{tab:"Agents",mode:"Solos",agent:"Suture"}}},setWidgetState:async function(value){window.savedCalls.push(value)}};</script>'+source);
    assert((await page.locator('[data-layout="desk"] main').innerText()).includes('Suture'));
    await page.locator('[data-layout="desk"] [data-agent="Lattice"]').click();
    assert.equal(await page.evaluate(()=>window.savedCalls.at(-1).modelContent.menu.agent),'Lattice');
    await page.evaluate(()=>window.dispatchEvent(new CustomEvent('openai:set_globals',{detail:{globals:{widgetState:{modelContent:{menu:{tab:'Dossiers',mode:'Duos',agent:'Guise'}}}}}})));
    assert((await page.locator('[data-layout="desk"] main').innerText()).includes('selected Dossier'));
    await page.setViewportSize({width:1024,height:900});
    await page.setContent(source);
    await page.screenshot({path:path.join(__dirname,'../docs/mockups/main-menu-review-desktop.png'),fullPage:true});
    assert.deepEqual(problems,[]);
    console.log('Menu preview: six sections, two layouts, four widths, agent/mode selection and Stocks→Mint passed; no runtime errors or horizontal overflow');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode=1; });
