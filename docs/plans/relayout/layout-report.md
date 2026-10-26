# Re-layout, as generated (tools/relayout-layout.cjs)

Checks on the placed layout: **all pass**

132 rooms (17 are elevator shaft pieces), 182 doors, 28 stairs and ramps, 5 elevator shafts, 6 vents, 8 secret exits, 2 ladders, 2 ziplines.

## Stairs and ramps as placed
| Id | Kind | From | To | Position | Direction | Width | Tier |
|---|---|---|---|---|---|---|---|
| grandstair | Grand stair | G g_lobby | M m_stairhall | (0, 139) | -z | 24 | 0 |
| escalator_w | Escalator ramp | G g_atrium | M m_balcony | (-46, -4) | +z | 12 | 0 |
| escalator_e | Escalator ramp | G g_atrium | M m_balcony | (46, -62) | +z | 12 | 0 |
| corner_nw | Switchback stair | G g_gallery | M m_gallery | (-91, -59) | -x switchback | 14 | 0 |
| corner_ne | Switchback stair | G g_ballroom | M m_ball_gal | (95, -65) | +x switchback | 14 | 0 |
| corner_sw | Switchback stair | G g_library | M m_wine | (-110, 105) | +z switchback | 14 | 0 |
| corner_se | Switchback stair | G g_lounge | M m_cigar | (103, 95) | +z switchback | 14 | 0 |
| terrace_stair_w | Switchback stair | M m_gallery | T t_ter_w | (-108, -15) | -z switchback | 14 | 0 |
| terrace_stair_e | Switchback stair | M m_ball_gal | T t_ter_e | (108, -34) | -z switchback | 14 | 0 |
| roof_stair | Roof stair | T t_ter_w | R r_deck_w | (-108, 55) | +z switchback | 14 | 0 |
| wing_grand_stair | Grand stair | G wg_casino | M wm_lobby | (210, 81) | -z | 24 | 0 |
| wing_stair_m_t | Switchback stair | M wm_bar | T wt_terrace | (175, 85) | +z switchback | 14 | 0 |
| wing_stair_t_r | Roof stair | T wt_arcade | R wr_garden | (243, 15) | +z switchback | 14 | 0 |
| wing_deck_stair | Stair | R wr_garden | S wd_skydeck | (269, -30) | -x switchback | 14 | 0 |
| wing_deck_stair_2 | Stair | R wr_garden | S wd_skydeck | (268, -69) | +z switchback | 14 | 0 |
| staff_b_g | Staff stair | B b_stores_e1 | G g_service_n | (85, -91) | +x switchback | 14 | 1 |
| staff_g_m | Staff stair | G g_kitchen | M m_offices | (-45, -108) | -z switchback | 14 | 1 |
| staff_b_g_s | Staff stair | B b_stores_w2 | G g_coat | (-107, 57) | +x switchback | 14 | 1 |
| staff_g_m_s | Staff stair | G g_pantry | M m_catering | (60, -145) | +z switchback | 14 | 1 |
| wing_staff_b_g | Staff stair | B wb_linen | G wg_cage | (172, -45) | +z switchback | 14 | 1 |
| wing_staff_g_m | Staff stair | G wg_cage | M wm_housekeeping | (192, -60) | -x switchback | 14 | 1 |
| plant_stair | Staff stair | T t_east | R r_plant | (75, -107) | +z switchback | 14 | 1 |
| wing_plant_stair | Staff stair | T wt_arcade | R wr_plant | (230, -41) | -z switchback | 14 | 1 |
| guard_b_g | Guard stair | B b_gate | G g_kitchen | (0, -125) | +z switchback | 14 | 2 |
| guard_m_t | Guard stair | M m_hub | T t_guard_nw | (-31, -94) | -z switchback | 14 | 2 |
| wing_guard_stair | Guard stair | B wb_security | G wg_cage | (170, -70) | +x switchback | 14 | 2 |
| guard_t_r | Guard stair | T t_east | R r_deck | (75, -5) | +z switchback | 14 | 2 |
| sanctum_stair | Executive stair | R r_summit | S s_stairhead | (-9, -60) | -x switchback | 14 | 4 |

## Elevator shafts
| Shaft | Level | Room | In | Stop | Rect |
|---|---|---|---|---|---|
| E1 Gallery glass elevator | G | el_E1_G | g_gallery | yes | (-87, -14) to (-75, -2) |
| E1 Gallery glass elevator | M | el_E1_M | m_gallery | yes | (-87, -14) to (-75, -2) |
| E1 Gallery glass elevator | T | el_E1_T | t_west | yes | (-87, -14) to (-75, -2) |
| E2 Atrium glass elevator | G | el_E2_G | g_atrium | yes | (39, 0) to (51, 12) |
| E2 Atrium glass elevator | M | el_E2_M | m_balcony | yes | (39, 0) to (51, 12) |
| E2 Atrium glass elevator | T | el_E2_T | t_great | passes | (39, 0) to (51, 12) |
| E2 Atrium glass elevator | R | el_E2_R | r_deck | yes | (39, 0) to (51, 12) |
| E3 Casino glass elevator | G | el_E3_G | wg_casino | yes | (239, 74) to (251, 86) |
| E3 Casino glass elevator | M | el_E3_M | wm_bar | yes | (239, 74) to (251, 86) |
| E3 Casino glass elevator | T | el_E3_T | wt_arcade | yes | (239, 74) to (251, 86) |
| E4 Hotel glass elevator | G | el_E4_G | wg_entry | yes | (224, 104) to (236, 116) |
| E4 Hotel glass elevator | M | el_E4_M | wm_bar | yes | (224, 104) to (236, 116) |
| E4 Hotel glass elevator | T | el_E4_T | wt_arcade | yes | (224, 104) to (236, 116) |
| E4 Hotel glass elevator | R | el_E4_R | wr_garden | yes | (224, 104) to (236, 116) |
| E5 Sanctum elevator (locked) | T | el_E5_T | t_great | yes | (18, -60) to (28, -50) |
| E5 Sanctum elevator (locked) | R | el_E5_R | r_summit | yes | (18, -60) to (28, -50) |
| E5 Sanctum elevator (locked) | S | el_E5_S | s_foyer | yes | (18, -60) to (28, -50) |

## Clearance reach (from the grand lobby, Sanctum elevator unlocked)
| Cap | Rooms reached | Not reached |
|---|---|---|
| 0 | 51 | none |
| 1 | 90 | none |
| 2 | 110 | none |
| 3 | 125 | none |
| 4 | 131 | none |

## Independent routes in (from the 12 insertion points)
| Objective | On foot, to the antechamber or foyer | All routes |
|---|---|---|
| Vault A | 2 | 3 |
| Vault B | 3 | 3 |
| Vault C | 2 | 3 |
| Vault D | 3 | 3 |
| Vault E | 2 | 3 |
| The Sanctum foyer | 5 | 5 |
| The Package room | 5 | 2 |
