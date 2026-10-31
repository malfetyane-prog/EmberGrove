// Game content for the Ember Grove world. Mirrors EmberGrove/Model/Content.swift.

export const CATEGORIES = {
  studying: { title: 'Studying', icon: 'cap', color: '#8E7CF0' },
  working: { title: 'Working', icon: 'briefcase', color: '#F5A524' },
  reading: { title: 'Reading', icon: 'book', color: '#5FB386' },
  creating: { title: 'Projects', icon: 'brush', color: '#E8674A' },
  other: { title: 'Other', icon: 'sparkles', color: '#6FA8DC' },
};

export const AMBIENCE = {
  none: { title: 'Silence', icon: 'mute' },
  campfire: { title: 'Campfire', icon: 'flame' },
  rain: { title: 'Soft Rain', icon: 'rain' },
  breeze: { title: 'Forest Breeze', icon: 'wind' },
  lofi: { title: 'Lo-fi Beats', icon: 'note' },
  binaural: { title: 'Focus Waves', icon: 'headphones', hint: 'Binaural beta waves. Best with headphones.' },
};

export const PATHS = {
  hearth: { title: 'Hearth', tagline: 'A warm, steady keeper who builds and gathers friends around the fire.' },
  bloom: { title: 'Bloom', tagline: 'A gentle gardener whose glow coaxes flowers and creatures out of hiding.' },
  starlight: { title: 'Starlight', tagline: 'A curious wanderer drawn to secrets, maps, and the quiet of the night sky.' },
};

export const FLAMES = {
  amber: { name: 'Amber', core: '#FF9A1F', glow: '#FFD27A' },
  gold: { name: 'Hearth Gold', core: '#FFC524', glow: '#FFE89A' },
  rose: { name: 'Rosefire', core: '#FF6F91', glow: '#FFB8C8' },
  jade: { name: 'Jadeleaf', core: '#4FD08A', glow: '#B5F2CC' },
  azure: { name: 'Azure Star', core: '#5AB4FF', glow: '#BFE2FF' },
  violet: { name: 'Moonviolet', core: '#A587FF', glow: '#DCCFFF' },
};

const v = (id, name, blurb, color) => ({ id, name, blurb, color });

export const AREAS = [
  { id: 'clearing', name: 'The Hearth Clearing', blurb: 'A quiet clearing around a long-cold campfire.', unlockMinutes: 0, xStart: 0, xEnd: 520 },
  { id: 'brook', name: 'Willowbrook', blurb: 'A sleepy brook that has forgotten how to sing.', unlockMinutes: 180, xStart: 520, xEnd: 900 },
  { id: 'oak', name: 'The Old Oak', blurb: "The grove's oldest tree, dreaming under a blanket of frost.", unlockMinutes: 600, xStart: 900, xEnd: 1250 },
  { id: 'ridge', name: 'Starlit Ridge', blurb: 'A high meadow where the sky feels close enough to touch.', unlockMinutes: 1500, xStart: 1250, xEnd: 1600 },
];

export const LANDMARKS = [
  { id: 'mushroomRing', name: 'Mushroom Ring', area: 'clearing', blurb: 'A circle of sleeping toadstools.',
    restoredText: 'The toadstools stretch awake and glow softly at their spots.',
    variants: [v('crimson', 'Crimson Caps', 'Classic red caps with cream spots.', '#D9534F'), v('glowcap', 'Glowcaps', 'Pale caps that shine blue at night.', '#7FC8FF')],
    x: 120, y: 448, companion: 'mosslings' },
  { id: 'meadow', name: 'Wildflower Meadow', area: 'clearing', blurb: 'Bare earth that remembers being a meadow.',
    restoredText: 'Flowers spill across the clearing and bees arrive within the hour.',
    variants: [v('sunflowers', 'Sunflowers', 'Tall, cheerful, golden.', '#F7C548'), v('bluebells', 'Bluebells', 'A shy sea of nodding blue.', '#7C8CE8')],
    x: 400, y: 452 },
  { id: 'stoneLanterns', name: 'Stone Lanterns', area: 'clearing', blurb: 'Two mossy lanterns, empty and dark.',
    restoredText: 'Ember shares a little of its flame. The path is lit again.',
    variants: [v('warm', 'Warm Light', 'Honey-colored and cozy.', '#FFC968'), v('moon', 'Moonlight', 'Cool and silvery.', '#C9D7FF')],
    x: 40, y: 420 },
  { id: 'lilyPond', name: 'Lily Pond', area: 'brook', blurb: 'A still pool choked with dead reeds.',
    restoredText: 'The water clears. Lily pads unfold, and something croaks hello.',
    variants: [v('pink', 'Pink Lilies', 'Soft and blushing.', '#FFB7CF'), v('white', 'Moon Lilies', 'White blossoms that open at dusk.', '#F4F1FF')],
    x: 600, y: 470, companion: 'pebble' },
  { id: 'willowBridge', name: 'Willow Bridge', area: 'brook', blurb: 'A broken footbridge over the brook.',
    restoredText: 'Willow branches weave themselves into a sturdy little bridge.',
    variants: [v('willow', 'Living Willow', 'Green and leafy.', '#7FAF5A'), v('cedar', 'Cedar Planks', 'Warm red wood.', '#B0643C')],
    x: 740, y: 430 },
  { id: 'waterWheel', name: 'Water Wheel', area: 'brook', blurb: 'A tiny mill whose wheel has stopped.',
    restoredText: 'The wheel creaks, then turns. The brook remembers its song.',
    variants: [v('red', 'Red Roof', 'A bright red mill roof.', '#C94A47'), v('blue', 'Blue Roof', 'A cool blue mill roof.', '#4F7CAC')],
    x: 850, y: 425, companion: 'wren' },
  { id: 'oldOak', name: 'The Old Oak', area: 'oak', blurb: 'A vast, bare tree, deep in a winter dream.',
    restoredText: 'Leaves rush out along every branch. The Old Oak opens one sleepy eye.',
    variants: [v('summer', 'Summer Canopy', 'Deep, cool green.', '#4E8A43'), v('autumn', 'Autumn Canopy', 'Gold and copper forever.', '#E08A3C')],
    x: 1060, y: 440, companion: 'hoot' },
  { id: 'treehouse', name: 'Treehouse Library', area: 'oak', blurb: "Planks wedged high in the Old Oak's branches.",
    restoredText: 'A tiny library with a round window. Ember already has a favorite chair.',
    variants: [v('honey', 'Honey Wood', 'Light and sunny.', '#E3A962'), v('plum', 'Plum Shingles', 'Dusky purple roof.', '#7A5C9E')],
    x: 1110, y: 250, requiresLandmark: 'oldOak' },
  { id: 'fireflyHollow', name: 'Firefly Hollow', area: 'oak', blurb: 'A hollow log, dark inside.',
    restoredText: 'A thousand fireflies pour out of the hollow and drift into the trees.',
    variants: [v('gold', 'Golden Swarm', 'Classic warm fireflies.', '#FFE07A'), v('green', 'Green Swarm', 'Minty, glimmering light.', '#B5F2A0')],
    x: 1200, y: 460, companion: 'glimmer' },
  { id: 'standingStones', name: 'Standing Stones', area: 'ridge', blurb: 'Three old stones with faded carvings.',
    restoredText: 'The carvings glow, tracing the shapes of constellations.',
    variants: [v('azure', 'Azure Runes', 'Sky-blue glow.', '#7FC8FF'), v('violet', 'Violet Runes', 'Twilight glow.', '#B79CFF')],
    x: 1330, y: 420, companion: 'nox' },
  { id: 'moonflowers', name: 'Moonflower Garden', area: 'ridge', blurb: 'Closed buds that wait for something.',
    restoredText: 'The moonflowers open all at once, like a held breath let go.',
    variants: [v('silver', 'Silver Blooms', 'Pale and luminous.', '#E6ECFF'), v('indigo', 'Indigo Blooms', 'Deep and velvety.', '#6A6FD8')],
    x: 1450, y: 455 },
  { id: 'starShrine', name: 'The Star Shrine', area: 'ridge', blurb: 'A hidden arch at the very top of the ridge, shown on an old map.',
    restoredText: 'A small star settles inside the arch, and the whole grove hums.',
    variants: [v('dawn', 'Dawn Star', 'Rosy gold.', '#FFC2A0'), v('dusk', 'Dusk Star', 'Lilac silver.', '#DCCFFF')],
    x: 1550, y: 395, requiresCurio: 'starMap' },
];

export const COMPANIONS = [
  { id: 'tansy', name: 'Tansy', species: 'Fox spirit', blurb: 'A curious fox with a tail like a dandelion clock. She followed the smoke.',
    arrivesWithChapter: 'ch3',
    memories: { 3: 'Tansy curled up beside the hearth and fell asleep with her nose on Ember\'s foot.', 6: 'Tansy admitted she used to live here, long ago, before the fire went out.', 10: 'Tansy brought a single warm coal from somewhere far away and set it in the hearth. "For luck."' },
    gifts: { 3: { cosmetic: 'knitScarf' }, 6: { seeds: 40 }, 10: { cosmetic: 'rose' } } },
  { id: 'mosslings', name: 'The Mosslings', species: 'Snail family', blurb: 'Five tiny snails who live in the mushroom ring. They never hurry.',
    homeLandmark: 'mushroomRing',
    memories: { 3: 'The Mosslings left a silvery trail that spelled, very slowly, "hi".', 6: "The smallest Mossling rode on Ember's head for a whole afternoon.", 10: 'The Mosslings wove a crown of tiny flowers. It took them a month.' },
    gifts: { 3: { seeds: 25 }, 6: { cosmetic: 'flowerCrown' }, 10: { seeds: 80 } } },
  { id: 'pebble', name: 'Pebble', species: 'Pond frog', blurb: 'A round green frog who is certain he is a great singer.',
    homeLandmark: 'lilyPond',
    memories: { 3: 'Pebble performed his finest song. Ember clapped politely.', 6: 'Pebble showed Ember the best lily pad for watching dragonflies.', 10: 'Pebble wrote a song about Ember. It has eleven verses.' },
    gifts: { 3: { seeds: 30 }, 6: { decoration: 'steppingStones' }, 10: { seeds: 80 } } },
  { id: 'wren', name: 'Wren', species: 'Little brown bird', blurb: 'A busy bird who keeps the water wheel free of twigs.',
    homeLandmark: 'waterWheel',
    memories: { 3: 'Wren taught Ember three new whistles.', 6: 'Wren brought news from beyond the ridge: the sky is wider there.', 10: "Wren built a nest right above the hearth, so she'd never be far." },
    gifts: { 3: { cosmetic: 'bellCollar' }, 6: { seeds: 40 }, 10: { decoration: 'birdhouse' } } },
  { id: 'hoot', name: 'Old Hoot', species: 'Owl', blurb: "The oak's keeper. Wise, a little deaf, very fond of naps.",
    homeLandmark: 'oldOak',
    memories: { 3: "Old Hoot told a story about the grove's first spark. He fell asleep halfway.", 6: 'Old Hoot remembered the rest: the first spark was a promise, kept every day.', 10: 'Old Hoot named Ember a Keeper of the Grove, then took a very long nap.' },
    gifts: { 3: { seeds: 30 }, 6: { cosmetic: 'roundGlasses' }, 10: { seeds: 100 } } },
  { id: 'glimmer', name: 'Glimmer', species: 'Firefly queen', blurb: 'Tiny, bright, and very much in charge.',
    homeLandmark: 'fireflyHollow',
    memories: { 3: "Glimmer's court performed a light show in Ember's honor.", 6: "Glimmer confessed that fireflies learned to glow by watching Ember's kind.", 10: 'Glimmer gave Ember a firefly to keep. It sleeps in the moss cap.' },
    gifts: { 3: { seeds: 35 }, 6: { decoration: 'fairyLights' }, 10: { seeds: 100 } } },
  { id: 'nox', name: 'Nox', species: 'Star hare', blurb: 'A silver hare who only comes out when the stars do.',
    homeLandmark: 'standingStones',
    memories: { 3: 'Nox showed Ember how to find the North Lantern in the sky.', 6: 'Nox and Ember counted shooting stars until they lost count.', 10: "Nox said Ember's flame is visible from the stars. They're watching, kindly." },
    gifts: { 3: { cosmetic: 'starCirclet' }, 6: { seeds: 50 }, 10: { seeds: 120 } } },
];

export const COSMETICS = [
  { id: 'acornCap', name: 'Acorn Cap', slot: 'head', unlock: { level: 3 }, blurb: 'Snug, sturdy, slightly too big.' },
  { id: 'mushroomHat', name: 'Toadstool Hat', slot: 'head', unlock: { seeds: 60 }, blurb: 'Borrowed from the Mosslings. Permanently.' },
  { id: 'flowerCrown', name: 'Flower Crown', slot: 'head', unlock: { gift: 'mosslings' }, blurb: 'Woven very, very slowly.' },
  { id: 'starCirclet', name: 'Star Circlet', slot: 'head', unlock: { gift: 'nox' }, blurb: 'A thin band holding a fallen star.' },
  { id: 'leafScarf', name: 'Leaf Scarf', slot: 'neck', unlock: { level: 6 }, blurb: 'Two leaves, carefully knotted.' },
  { id: 'knitScarf', name: 'Knit Scarf', slot: 'neck', unlock: { gift: 'tansy' }, blurb: 'Smells faintly of woodsmoke and fox.' },
  { id: 'bellCollar', name: 'Bell Collar', slot: 'neck', unlock: { gift: 'wren' }, blurb: 'Jingles at every hop.' },
  { id: 'roundGlasses', name: 'Reading Glasses', slot: 'face', unlock: { seeds: 40 }, blurb: 'For serious study and looking wise.' },
  { id: 'amber', name: 'Amber Flame', slot: 'flame', unlock: { starter: true }, blurb: "Ember's first flame." },
  { id: 'gold', name: 'Hearth Gold', slot: 'flame', unlock: { path: 'hearth' }, blurb: 'Steady as a home fire.' },
  { id: 'jade', name: 'Jadeleaf', slot: 'flame', unlock: { path: 'bloom' }, blurb: 'The color of new leaves.' },
  { id: 'azure', name: 'Azure Star', slot: 'flame', unlock: { path: 'starlight' }, blurb: 'Borrowed from the night.' },
  { id: 'rose', name: 'Rosefire', slot: 'flame', unlock: { gift: 'tansy' }, blurb: "Tansy's lucky coal." },
  { id: 'violet', name: 'Moonviolet', slot: 'flame', unlock: { curios: 12 }, blurb: 'Kindled by a full collection.' },
];

export const DECORATIONS = [
  { id: 'steppingStones', name: 'Stepping Stones', blurb: 'A winding path to the hearth.', cost: 30 },
  { id: 'toadstoolStools', name: 'Toadstool Stools', blurb: 'Seats for visiting friends.', cost: 35 },
  { id: 'windChimes', name: 'Wind Chimes', blurb: 'Hollow reeds that hum in the breeze.', cost: 45 },
  { id: 'birdhouse', name: 'Birdhouse', blurb: 'A cozy box on a post.', cost: 50 },
  { id: 'paperLanterns', name: 'Paper Lanterns', blurb: 'A string of warm lanterns over the clearing.', cost: 60 },
  { id: 'fairyLights', name: 'Firefly Lights', blurb: 'Little jars of borrowed starlight.', cost: 80 },
];

export const CURIOS = [
  { id: 'acornTop', name: 'Polished Acorn', blurb: 'Smooth as a river stone, warm as a pocket.', icon: 'acorn', area: 'clearing' },
  { id: 'clover', name: 'Four-Leaf Clover', blurb: 'Lucky, obviously.', icon: 'clover', area: 'clearing' },
  { id: 'emberGlass', name: 'Ember Glass', blurb: 'A shard of glass that holds a tiny glow.', icon: 'flame', area: 'clearing' },
  { id: 'tinyBell', name: 'Tiny Brass Bell', blurb: 'Rings in a key no one has heard before.', icon: 'bell', area: 'clearing' },
  { id: 'pressedViolet', name: 'Pressed Violet', blurb: 'Tucked into the hearthstones, long ago.', icon: 'flower', area: 'clearing' },
  { id: 'riverGlass', name: 'River Glass', blurb: 'Sea-green and frosted by the brook.', icon: 'drop', area: 'brook' },
  { id: 'wishingPebble', name: 'Wishing Pebble', blurb: 'Perfectly round, with a hole in the middle.', icon: 'ring', area: 'brook' },
  { id: 'kingfisherFeather', name: 'Kingfisher Feather', blurb: 'Bluer than anything has a right to be.', icon: 'feather', area: 'brook' },
  { id: 'ladybugCharm', name: 'Ladybug Charm', blurb: 'A tiny carved ladybug. It might be real.', icon: 'ladybug', area: 'brook' },
  { id: 'oldKey', name: 'Old Iron Key', blurb: 'It fits nothing in the grove. Yet.', icon: 'key', area: 'oak' },
  { id: 'fireflyJar', name: 'Firefly Jar', blurb: 'Empty, but still faintly warm.', icon: 'jar', area: 'oak' },
  { id: 'unsentLetter', name: 'Unsent Letter', blurb: '"Dear Grove, I\'ll come back. I promise."', icon: 'letter', area: 'oak' },
  { id: 'mapleSeed', name: 'Maple Spinner', blurb: 'Twirls all the way down every time.', icon: 'wind', area: 'oak' },
  { id: 'moonstone', name: 'Moonstone', blurb: "Glows a little brighter when you're focusing.", icon: 'moon', area: 'ridge' },
  { id: 'starMap', name: 'Star Map', blurb: 'A faded map with one star circled, at the top of the ridge.', icon: 'map', area: 'ridge' },
  { id: 'cometDust', name: 'Comet Dust', blurb: 'A pinch of sparkle in a seed pod.', icon: 'sparkles', area: 'ridge' },
  { id: 'musicBox', name: 'Tiny Music Box', blurb: 'Plays the first four notes of a lullaby.', icon: 'note', area: 'ridge' },
];

export const CHAPTERS = [
  { id: 'ch1', number: 1, title: 'The Cold Hearth', trigger: { start: true }, pages: [
    'Once, the grove was warm. Fireflies lit the paths, the brook sang, and every creature knew the way home by the glow of the hearth.',
    'Then the fire went out. No one quite remembers why. The frost crept in, and one by one the creatures drifted away.',
    'But in the ashes, something small is still glowing. It blinks, yawns, and looks up at you.',
    "Its name is {name}. And it's been waiting for someone to sit with it a while."] },
  { id: 'ch2', number: 2, title: 'A Spark Returns', trigger: { firstSession: true }, pages: [
    'While you worked, {name} worked too, gathering twigs and breathing on the old coals.',
    "Now the hearth is lit. It's a small fire, but it's a real one.",
    'Somewhere in the dark, the grove notices.'] },
  { id: 'ch3', number: 3, title: 'Footprints in the Frost', trigger: { firstRestoration: true }, pages: [
    'The morning after the first restoration, {name} finds a line of small paw prints leading to the hearth.',
    'A fox with a dandelion-clock tail is sitting in the warmth like she owns it. "I\'m Tansy," she says. "I saw the smoke."',
    '"If you\'re bringing the grove back," she adds, "I\'d like to watch."'] },
  { id: 'ch4', number: 4, title: 'The Brook Remembers', trigger: { area: 'brook' }, pages: [
    'The frost east of the clearing has thinned enough to walk through.',
    'Beyond it, a brook lies still, as if holding its breath. {name} dips a foot in. Ice cracks, just a little.',
    'Tansy says the brook used to sing. Perhaps it could again.'] },
  { id: 'ch5', number: 5, title: 'The Shape of a Flame', trigger: { pathChosen: true }, pages: [
    '{name} has been changing. Slowly, the way a seed becomes a sprout without anyone catching it in the act.',
    'Today the change is impossible to miss. {name} stands a little taller, and the flame inside has found its own shape.',
    'Tansy circles twice, sniffs, and decides she approves.'] },
  { id: 'ch6', number: 6, title: 'The Old Oak Wakes', trigger: { landmark: 'oldOak' }, pages: [
    "The Old Oak's leaves came back all at once, with a sound like a thousand pages turning.",
    'From a hollow high in the trunk, an owl blinks down. "Ah," says Old Hoot. "A Keeper. It\'s been a while."',
    '"The fire didn\'t go out on its own, you know," he adds, and then, infuriatingly, falls asleep.'] },
  { id: 'ch7', number: 7, title: 'Beyond the Ridge', trigger: { area: 'ridge' }, pages: [
    'Past the oak the land rises into a high meadow, close to the sky.',
    "At night the stars here are so bright that {name}'s flame flickers back at them, like it's answering.",
    "Old Hoot, awake for once, says the first Keepers came from up here. Somewhere there's a map."] },
  { id: 'ch8', number: 8, title: 'The Star Map', trigger: { curio: 'starMap' }, pages: [
    'Tucked under a stone, wrapped in waxed leaves: a map of the grove, drawn long ago.',
    "Every place you've restored is on it. So is one more, a small arch at the very top of the ridge, with a single star drawn inside.",
    'Beside it, in tiny handwriting: "Where the promise is kept."'] },
  { id: 'ch9', number: 9, title: 'A Grove Rekindled', trigger: { allRestored: true }, pages: [
    'Every lantern is lit. The brook sings, the oak rustles, and the ridge glitters under its stars.',
    'Old Hoot finally finishes his story: the fire went out because no one tended it. Not because of a curse, just forgetting.',
    '"And it came back," says Tansy, "because someone remembered. A little, every day."',
    '{name} leans against you, warm and bright. The grove will keep growing. So will you.'] },
];

export const STAGES = [
  { index: 0, minLevel: 1, path: null, name: 'Spark', blurb: 'A tiny ember-spirit, newly woken. Small, warm, curious about everything.' },
  { index: 1, minLevel: 4, path: null, name: 'Kindle', blurb: 'Bigger and braver. The sprout on its cap has grown a second leaf.' },
  { index: 2, minLevel: 8, path: 'hearth', name: 'Hearthling', blurb: 'Its flame now burns on top for all to see. Friends gather wherever it sits.' },
  { index: 3, minLevel: 15, path: 'hearth', name: 'Hearthkeeper', blurb: "Flame-tufted and steady. The grove feels warmer just because it's there." },
  { index: 4, minLevel: 25, path: 'hearth', name: 'Grove Hearth', blurb: 'A living hearth. Embers drift around it like fireflies.' },
  { index: 2, minLevel: 8, path: 'bloom', name: 'Bloomling', blurb: "Leafy ears and a budding flower. Plants lean toward it like it's the sun." },
  { index: 3, minLevel: 15, path: 'bloom', name: 'Bloomwarden', blurb: 'Flowers open wherever it naps. Creatures trust it instantly.' },
  { index: 4, minLevel: 25, path: 'bloom', name: 'Verdant Heart', blurb: 'A walking spring. Butterflies follow it everywhere.' },
  { index: 2, minLevel: 8, path: 'starlight', name: 'Glimmerling', blurb: 'Gauzy wings and starry antennae. It hums when the stars come out.' },
  { index: 3, minLevel: 15, path: 'starlight', name: 'Starwanderer', blurb: 'Its wings catch moonlight. It always seems to know where secrets are.' },
  { index: 4, minLevel: 25, path: 'starlight', name: 'Lantern of the Sky', blurb: 'Tiny stars orbit it. Travelers could find their way home by its glow.' },
];

export const ABILITIES = [
  { id: 'warmGlow', name: 'Warm Glow', blurb: 'Every focused minute becomes Glow.', stage: 0, path: null },
  { id: 'emberSense', name: 'Ember Sense', blurb: '+5% chance to make a discovery.', stage: 1, path: null },
  { id: 'steadyFlame', name: 'Steady Flame', blurb: '+10% Seeds from sessions.', stage: 2, path: 'hearth' },
  { id: 'hearthSong', name: 'Hearth Song', blurb: 'Friends grow close 25% faster.', stage: 3, path: 'hearth' },
  { id: 'everflame', name: 'Everflame', blurb: '+10% Glow from every session.', stage: 4, path: 'hearth' },
  { id: 'greenThumb', name: 'Green Thumb', blurb: 'Friends grow close 25% faster.', stage: 2, path: 'bloom' },
  { id: 'gentleRain', name: 'Gentle Rain', blurb: '+15% Seeds from sessions.', stage: 3, path: 'bloom' },
  { id: 'evergreen', name: 'Evergreen', blurb: '+10% Glow from every session.', stage: 4, path: 'bloom' },
  { id: 'wayfinder', name: 'Wayfinder', blurb: '+10% chance to make a discovery.', stage: 2, path: 'starlight' },
  { id: 'nightSight', name: 'Night Sight', blurb: 'Discoveries can happen in sessions of 5+ minutes.', stage: 3, path: 'starlight' },
  { id: 'astralTide', name: 'Astral Tide', blurb: '+10% Glow from every session.', stage: 4, path: 'starlight' },
];

export const ACHIEVEMENTS = [
  { id: 'firstSpark', title: 'First Spark', blurb: 'Complete your first focus session.', icon: 'flame' },
  { id: 'hourOfGlow', title: 'An Hour of Glow', blurb: 'Focus for 1 hour in total.', icon: 'clock' },
  { id: 'tenHours', title: 'Kindled', blurb: 'Focus for 10 hours in total.', icon: 'flame' },
  { id: 'fiftyHours', title: 'Bonfire', blurb: 'Focus for 50 hours in total.', icon: 'sun' },
  { id: 'hundredHours', title: 'Eternal Flame', blurb: 'Focus for 100 hours in total.', icon: 'star' },
  { id: 'fullCycle', title: 'Full Cycle', blurb: 'Complete a full Pomodoro cycle of focus rounds.', icon: 'clock' },
  { id: 'deepDive', title: 'Deep Dive', blurb: 'Focus for 60 minutes in one session.', icon: 'drop' },
  { id: 'earlyBird', title: 'Early Bird', blurb: 'Start a session before 8 AM.', icon: 'sun' },
  { id: 'nightOwl', title: 'Night Owl', blurb: 'Finish a session after 10 PM.', icon: 'moon' },
  { id: 'wellRounded', title: 'Well Rounded', blurb: 'Focus in four different categories.', icon: 'grid' },
  { id: 'steadyWeek', title: 'Steady Week', blurb: 'Focus on 5 different days in one week.', icon: 'calendar' },
  { id: 'pathfinder', title: 'Pathfinder', blurb: "Choose Ember's evolution path.", icon: 'branch' },
  { id: 'elder', title: 'Fully Grown', blurb: "Reach Ember's final form.", icon: 'crown' },
  { id: 'restorer', title: 'Restorer', blurb: 'Restore 6 places in the grove.', icon: 'leaf' },
  { id: 'explorer', title: 'Explorer', blurb: 'Unlock every area of the grove.', icon: 'map' },
  { id: 'trueFriend', title: 'True Friend', blurb: 'Reach 10 hearts with a companion.', icon: 'heart' },
  { id: 'collector', title: 'Collector', blurb: 'Discover 12 curios.', icon: 'box' },
  { id: 'rekindled', title: 'Grove Rekindled', blurb: 'Restore every place in the grove.', icon: 'tree' },
];

export const QUESTS = [
  { id: 'd.focus25', cadence: 'daily', title: 'Focus for 25 minutes', metric: 'minutes', target: 25, seeds: 10, glow: 30 },
  { id: 'd.focus60', cadence: 'daily', title: 'Focus for an hour', metric: 'minutes', target: 60, seeds: 20, glow: 50 },
  { id: 'd.twoSessions', cadence: 'daily', title: 'Complete 2 sessions', metric: 'sessions', target: 2, seeds: 12, glow: 30 },
  { id: 'd.reading', cadence: 'daily', title: 'Read for 15 minutes', metric: 'cat:reading', target: 15, seeds: 12, glow: 30 },
  { id: 'd.deep', cadence: 'daily', title: 'One session of 45+ minutes', metric: 'longest', target: 45, seeds: 20, glow: 50 },
  { id: 'd.morning', cadence: 'daily', title: 'Start a session before noon', metric: 'beforeNoon', target: 1, seeds: 10, glow: 25 },
  { id: 'd.study', cadence: 'daily', title: 'Study for 30 minutes', metric: 'cat:studying', target: 30, seeds: 14, glow: 35 },
  { id: 'w.threeHours', cadence: 'weekly', title: 'Focus for 3 hours this week', metric: 'minutes', target: 180, seeds: 50, glow: 120 },
  { id: 'w.fourDays', cadence: 'weekly', title: 'Focus on 4 different days', metric: 'days', target: 4, seeds: 45, glow: 100 },
  { id: 'w.categories', cadence: 'weekly', title: 'Focus in 3 different categories', metric: 'categories', target: 3, seeds: 40, glow: 90 },
  { id: 'w.tenSessions', cadence: 'weekly', title: 'Complete 10 sessions', metric: 'sessions', target: 10, seeds: 50, glow: 120 },
];

export const RENEWAL_MILESTONES = [45, 120, 240, 400, 600, 850, 1150, 1500, 1900, 2350, 2850, 3400];

export const byId = (list, id) => list.find((x) => x.id === id);
export const stageFor = (index, path) => STAGES.find((s) => s.index === index && (index < 2 || s.path === path)) || STAGES[0];
