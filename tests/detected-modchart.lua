-- Run from the repository root with LuaJIT. Simulate engine objects for the
-- complete choreography, including sustain notes and negative lane speed.
local nativeDofile = dofile
function dofile(path)
    return nativeDofile((path:gsub('^assets/data/', 'assets/preload/data/')))
end
bpm, songPos, scrollSpeed = 150, 0, 1.8
camNotes = {x=0, y=0, angle=0}
local names, speeds = {}, {}
for i=0,7 do
    _G['receptor_'..i] = {x=100+i*112, y=50, angle=0, alpha=1}
    for sustain=0,1 do
        local name = 'note_test_'..i..'_'..sustain
        names[#names+1] = name
        _G[name] = {isDead=false, mustPress=i>=4, isSustain=sustain==1,
            isParent=false, data=i%4, strumTime=1000, yNoteOff=0}
    end
end
function getNotes() return names end
function setLaneScrollspeed(lane, speed) speeds[lane] = speed end
nativeDofile('assets/preload/data/songs/detected/modchart.lua')
start('detected')
songStart('detected')
local moved, reversed = false, false
local function finite(v)
    assert(type(v)=='number' and v==v and math.abs(v)<math.huge, 'non-finite transform')
end
for frame=0,12000 do
    songPos = frame * 1000/60
    for _,name in ipairs(names) do _G[name].strumTime=songPos+700 end
    update(1/60)
    finite(camNotes.angle)
    for i=0,7 do
        local r = _G['receptor_'..i]
        finite(r.x); finite(r.y); finite(r.angle); finite(r.alpha); finite(speeds[i])
        moved = moved or math.abs(r.x-(100+i*112))>1
        reversed = reversed or speeds[i]<0
    end
    for _,name in ipairs(names) do
        local n = _G[name]
        finite(n.x); finite(n.y); finite(n.angle); finite(n.alpha)
    end
end
assert(moved, 'choreography did not move receptors')
assert(reversed, 'reverse choreography did not run')
print('PASS: Detected modchart: 12001 frames, 8 lanes, tap/sustain transforms, movement and reverse')
