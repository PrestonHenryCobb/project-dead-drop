"""Author/export/preview the same original recipe geometry in Blender. Run with Blender --background --python."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Matrix, Vector

root = Path(__file__).resolve().parents[1]
out = root / 'assets/gala/sculptures'
definitions = json.loads((out / 'geometry.json').read_text())
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
basis = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
palette = {'Skin':'C28B69', 'Ink':'262125', 'Cloth':'20232A', 'Accent':'586D5C', 'Ivory':'EFE8DA',
           'Brass':'C89D54', 'Walnut':'2A1B15', 'Velvet':'581825', 'Warm':'FFB87B'}
materials = {}
for role, color in palette.items():
    mat = bpy.data.materials.new(role)
    def linear(value):
        value /= 255
        return value/12.92 if value <= .04045 else ((value+.055)/1.055)**2.4
    mat.diffuse_color = tuple(linear(int(color[i:i+2], 16)) for i in (0,2,4)) + (1,)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = mat.diffuse_color
    shader.inputs['Metallic'].default_value = .92 if role == 'Brass' else 0
    shader.inputs['Roughness'].default_value = .22 if role == 'Brass' else .78
    if role == 'Warm':
        shader.inputs['Emission Color'].default_value = mat.diffuse_color
        shader.inputs['Emission Strength'].default_value = .7
    materials[role] = mat

def primitive(s):
    if s['kind'] == 'Wedge':
        vertices = [(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)]
        mesh = bpy.data.meshes.new('Wedge')
        mesh.from_pydata(vertices, [], [(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)])
        obj = bpy.data.objects.new('Wedge',mesh)
        bpy.context.collection.objects.link(obj)
        local = Matrix.Diagonal(Vector(s['size']).to_4d())
        local[3][3] = 1
    elif s['kind'] == 'Cylinder':
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=.5, depth=1)
        obj = bpy.context.object
        # Blender cylinder axis Z -> Roblox cylinder axis X, before the recipe rotation.
        local = Matrix.Diagonal(Vector(s['size']).to_4d()) @ Matrix.Rotation(math.pi/2, 4, 'Y')
        local[3][3] = 1
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj = bpy.context.object
        local = Matrix.Diagonal(Vector(s['size']).to_4d())
        local[3][3] = 1
    rx,ry,rz = [math.radians(v) for v in s['rotation']]
    transform = Matrix.Translation(Vector(s['at'])) @ Matrix.Rotation(rx,4,'X') @ Matrix.Rotation(ry,4,'Y') @ Matrix.Rotation(rz,4,'Z')
    obj.matrix_world = basis @ transform @ local
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)
    return obj

all_assets=[]
groups={}
for name, definition in definitions.items():
    objects=[]
    for part in definition['parts']:
        obj=primitive(part['add'][0])
        for operation, shapes in [('UNION',part['add'][1:]),('DIFFERENCE',part.get('cut',[]))]:
            for s in shapes:
                cutter=primitive(s)
                bpy.context.view_layer.objects.active=obj
                mod=obj.modifiers.new('Authored plane', 'BOOLEAN')
                mod.operation=operation
                mod.solver='EXACT'
                mod.object=cutter
                bpy.ops.object.modifier_apply(modifier=mod.name)
                bpy.data.objects.remove(cutter,do_unlink=True)
        obj.name=name+'_'+part['name']
        obj.data.materials.clear()
        obj.data.materials.append(materials[part['role']])
        objects.append(obj)
        all_assets.append(obj)
    groups[name]=objects

# Export canonical assets at origin for source authoring/import; preview staging comes afterward.
bpy.ops.object.select_all(action='DESELECT')
for obj in all_assets: obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(out/'GalaSculptures.fbx'), use_selection=True, object_types={'MESH'},
                         apply_unit_scale=True, axis_forward='-Z', axis_up='Y', bake_anim=False)

# Neutral presentation: original character assembly plus environment assets, not a claimed Studio screenshot.
for name, objects in groups.items():
    if name in ('Head','Suit','Lapels','BowTie'):
        shift = Vector((-3.6, 0, 3.15 if name=='Head' else 1.6))
        if name=='Head':
            for obj in objects:
                obj.location.x *= .8
                obj.scale.x *= .8
    elif name=='Column':
        shift=Vector((2.8,1.8,3.3))
        for obj in objects:
            obj.location *= .3
            obj.scale *= .3
    elif name=='Chandelier':
        shift=Vector((0.1,0.4,4.9))
        for obj in objects:
            obj.location *= .62
            obj.scale *= .62
    else:
        shift=Vector((.9,-.6,.9))
        for obj in objects:
            obj.location *= .52
            obj.scale *= .52
    for obj in objects: obj.location += shift

ground=bpy.data.materials.new('Backdrop'); ground.diffuse_color=(.08,.09,.12,1)
bpy.ops.mesh.primitive_plane_add(size=200)
bpy.context.object.data.materials.append(ground)
def area(name,loc,power,size,color):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); obj.location=loc
    obj.rotation_euler=(Vector((0,0,2.5))-obj.location).to_track_quat('-Z','Y').to_euler()
area('Warm key',(-3,6,9),1400,6,(1,.79,.56))
area('Cool fill',(6,2,6),1000,5,(.45,.66,1))
area('Soft rim',(-1,-5,8),1800,4,(1,.88,.7))
data=bpy.data.cameras.new('Review'); camera=bpy.data.objects.new('Review',data); bpy.context.collection.objects.link(camera)
camera.location=(8,16,10)
camera.rotation_euler=(Vector((-.3,0,2.6))-camera.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO'; data.ortho_scale=12
scene=bpy.context.scene; scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32
scene.render.resolution_x=1600; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.world.color=(.12,.13,.17)
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(out/'asset-preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'GalaSculptures.blend'))
bpy.ops.render.render(write_still=True)
print('GALA_ASSET_RENDER',len(all_assets),'components')
