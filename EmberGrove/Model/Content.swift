import Foundation

// MARK: - Focus basics

enum FocusMode: String, Codable, CaseIterable, Identifiable {
    case countdown, stopwatch
    var id: String { rawValue }
    var title: String { self == .countdown ? "Timer" : "Stopwatch" }
}

enum FocusCategory: String, Codable, CaseIterable, Identifiable {
    case studying, working, reading, creating, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .studying: "Studying"
        case .working: "Working"
        case .reading: "Reading"
        case .creating: "Projects"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .studying: "graduationcap.fill"
        case .working: "briefcase.fill"
        case .reading: "book.fill"
        case .creating: "paintbrush.pointed.fill"
        case .other: "sparkles"
        }
    }

    var hex: UInt32 {
        switch self {
        case .studying: 0x8E7CF0
        case .working: 0xF5A524
        case .reading: 0x5FB386
        case .creating: 0xE8674A
        case .other: 0x6FA8DC
        }
    }
}

// MARK: - Content types

enum RewardItem: Codable, Hashable {
    case seeds(Int)
    case cosmetic(String)
    case decoration(String)
}

enum CosmeticSlot: String, Codable, CaseIterable, Identifiable {
    case head, neck, face, flame
    var id: String { rawValue }
    var title: String {
        switch self {
        case .head: "Head"
        case .neck: "Neck"
        case .face: "Face"
        case .flame: "Flame"
        }
    }
}

enum UnlockRule: Hashable {
    case starter
    case level(Int)
    case seeds(Int)
    case gift(companion: String)
    case path(EmberPath)
    case curios(Int)
}

struct Cosmetic: Identifiable, Hashable {
    let id: String
    let name: String
    let slot: CosmeticSlot
    let unlock: UnlockRule
    let blurb: String
}

struct WorldArea: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let unlockMinutes: Int
    /// Horizontal span in world units (the world is 1600 × 600).
    let xStart: Double
    let xEnd: Double
}

struct LandmarkVariant: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let hex: UInt32
}

struct Landmark: Identifiable, Hashable {
    let id: String
    let name: String
    let area: String
    let blurb: String
    let restoredText: String
    let variants: [LandmarkVariant]
    /// Anchor in world units, at the base of the landmark.
    let x: Double
    let y: Double
    var companion: String? = nil
    var requiresLandmark: String? = nil
    /// Hidden locations are invisible until this curio is discovered.
    var requiresCurio: String? = nil
}

struct Companion: Identifiable, Hashable {
    let id: String
    let name: String
    let species: String
    let blurb: String
    /// Landmark that brings this companion, or nil if they arrive with a story chapter.
    let homeLandmark: String?
    let arrivesWithChapter: String?
    let memories: [Int: String]
    let gifts: [Int: RewardItem]
}

struct Decoration: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let cost: Int
}

struct Curio: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let symbol: String
    let area: String
}

enum ChapterTrigger: Hashable {
    case start
    case firstSession
    case firstRestoration
    case areaUnlocked(String)
    case pathChosen
    case landmark(String)
    case curio(String)
    case allRestored
}

struct Chapter: Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let trigger: ChapterTrigger
    let pages: [String]
}

struct EvolutionStage: Hashable {
    let index: Int
    let minLevel: Int
    let path: EmberPath?
    let name: String
    let blurb: String
}

struct Ability: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let stage: Int
    let path: EmberPath?
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let symbol: String
}

enum QuestMetric: Hashable {
    case minutes
    case sessions
    case categoryMinutes(FocusCategory)
    case longestSession
    case startedBeforeNoon
    case distinctDays
    case distinctCategories
}

struct QuestTemplate: Identifiable, Hashable {
    enum Cadence { case daily, weekly }
    let id: String
    let cadence: Cadence
    let title: String
    let metric: QuestMetric
    let target: Int
    let seeds: Int
    let glow: Int
}

// MARK: - The content catalogue
// A world + character pair. Additional worlds and companions can be added as new catalogues.

struct GameContent {
    let areas: [WorldArea]
    let landmarks: [Landmark]
    let companions: [Companion]
    let cosmetics: [Cosmetic]
    let decorations: [Decoration]
    let curios: [Curio]
    let chapters: [Chapter]
    let stages: [EvolutionStage]
    let abilities: [Ability]
    let achievements: [Achievement]
    let quests: [QuestTemplate]
    /// Cumulative focus minutes at which a renewal (a restoration choice) is earned.
    let renewalMilestones: [Int]

    func landmark(_ id: String) -> Landmark? { landmarks.first { $0.id == id } }
    func area(_ id: String) -> WorldArea? { areas.first { $0.id == id } }
    func companion(_ id: String) -> Companion? { companions.first { $0.id == id } }
    func cosmetic(_ id: String) -> Cosmetic? { cosmetics.first { $0.id == id } }
    func decoration(_ id: String) -> Decoration? { decorations.first { $0.id == id } }
    func curio(_ id: String) -> Curio? { curios.first { $0.id == id } }
    func chapter(_ id: String) -> Chapter? { chapters.first { $0.id == id } }
    func achievement(_ id: String) -> Achievement? { achievements.first { $0.id == id } }

    func stage(index: Int, path: EmberPath?) -> EvolutionStage {
        stages.first { $0.index == index && (index < 2 || $0.path == path) } ?? stages[0]
    }

    static let grove = GameContent(
        areas: [
            WorldArea(id: "clearing", name: "The Hearth Clearing", blurb: "A quiet clearing around a long-cold campfire.",
                      unlockMinutes: 0, xStart: 0, xEnd: 520),
            WorldArea(id: "brook", name: "Willowbrook", blurb: "A sleepy brook that has forgotten how to sing.",
                      unlockMinutes: 180, xStart: 520, xEnd: 900),
            WorldArea(id: "oak", name: "The Old Oak", blurb: "The grove's oldest tree, dreaming under a blanket of frost.",
                      unlockMinutes: 600, xStart: 900, xEnd: 1250),
            WorldArea(id: "ridge", name: "Starlit Ridge", blurb: "A high meadow where the sky feels close enough to touch.",
                      unlockMinutes: 1500, xStart: 1250, xEnd: 1600),
        ],
        landmarks: [
            Landmark(id: "mushroomRing", name: "Mushroom Ring", area: "clearing",
                     blurb: "A circle of sleeping toadstools.",
                     restoredText: "The toadstools stretch awake and glow softly at their spots.",
                     variants: [
                        LandmarkVariant(id: "crimson", name: "Crimson Caps", blurb: "Classic red caps with cream spots.", hex: 0xD9534F),
                        LandmarkVariant(id: "glowcap", name: "Glowcaps", blurb: "Pale caps that shine blue at night.", hex: 0x7FC8FF),
                     ],
                     x: 120, y: 448, companion: "mosslings"),
            Landmark(id: "meadow", name: "Wildflower Meadow", area: "clearing",
                     blurb: "Bare earth that remembers being a meadow.",
                     restoredText: "Flowers spill across the clearing and bees arrive within the hour.",
                     variants: [
                        LandmarkVariant(id: "sunflowers", name: "Sunflowers", blurb: "Tall, cheerful, golden.", hex: 0xF7C548),
                        LandmarkVariant(id: "bluebells", name: "Bluebells", blurb: "A shy sea of nodding blue.", hex: 0x7C8CE8),
                     ],
                     x: 400, y: 452),
            Landmark(id: "stoneLanterns", name: "Stone Lanterns", area: "clearing",
                     blurb: "Two mossy lanterns, empty and dark.",
                     restoredText: "Ember shares a little of its flame. The path is lit again.",
                     variants: [
                        LandmarkVariant(id: "warm", name: "Warm Light", blurb: "Honey-colored and cozy.", hex: 0xFFC968),
                        LandmarkVariant(id: "moon", name: "Moonlight", blurb: "Cool and silvery.", hex: 0xC9D7FF),
                     ],
                     x: 40, y: 420),
            Landmark(id: "lilyPond", name: "Lily Pond", area: "brook",
                     blurb: "A still pool choked with dead reeds.",
                     restoredText: "The water clears. Lily pads unfold, and something croaks hello.",
                     variants: [
                        LandmarkVariant(id: "pink", name: "Pink Lilies", blurb: "Soft and blushing.", hex: 0xFFB7CF),
                        LandmarkVariant(id: "white", name: "Moon Lilies", blurb: "White blossoms that open at dusk.", hex: 0xF4F1FF),
                     ],
                     x: 600, y: 470, companion: "pebble"),
            Landmark(id: "willowBridge", name: "Willow Bridge", area: "brook",
                     blurb: "A broken footbridge over the brook.",
                     restoredText: "Willow branches weave themselves into a sturdy little bridge.",
                     variants: [
                        LandmarkVariant(id: "willow", name: "Living Willow", blurb: "Green and leafy.", hex: 0x7FAF5A),
                        LandmarkVariant(id: "cedar", name: "Cedar Planks", blurb: "Warm red wood.", hex: 0xB0643C),
                     ],
                     x: 740, y: 430),
            Landmark(id: "waterWheel", name: "Water Wheel", area: "brook",
                     blurb: "A tiny mill whose wheel has stopped.",
                     restoredText: "The wheel creaks, then turns. The brook remembers its song.",
                     variants: [
                        LandmarkVariant(id: "red", name: "Red Roof", blurb: "A bright red mill roof.", hex: 0xC94A47),
                        LandmarkVariant(id: "blue", name: "Blue Roof", blurb: "A cool blue mill roof.", hex: 0x4F7CAC),
                     ],
                     x: 850, y: 425, companion: "wren"),
            Landmark(id: "oldOak", name: "The Old Oak", area: "oak",
                     blurb: "A vast, bare tree, deep in a winter dream.",
                     restoredText: "Leaves rush out along every branch. The Old Oak opens one sleepy eye.",
                     variants: [
                        LandmarkVariant(id: "summer", name: "Summer Canopy", blurb: "Deep, cool green.", hex: 0x4E8A43),
                        LandmarkVariant(id: "autumn", name: "Autumn Canopy", blurb: "Gold and copper forever.", hex: 0xE08A3C),
                     ],
                     x: 1060, y: 440, companion: "hoot"),
            Landmark(id: "treehouse", name: "Treehouse Library", area: "oak",
                     blurb: "Planks wedged high in the Old Oak's branches.",
                     restoredText: "A tiny library with a round window. Ember already has a favorite chair.",
                     variants: [
                        LandmarkVariant(id: "honey", name: "Honey Wood", blurb: "Light and sunny.", hex: 0xE3A962),
                        LandmarkVariant(id: "plum", name: "Plum Shingles", blurb: "Dusky purple roof.", hex: 0x7A5C9E),
                     ],
                     x: 1110, y: 250, requiresLandmark: "oldOak"),
            Landmark(id: "fireflyHollow", name: "Firefly Hollow", area: "oak",
                     blurb: "A hollow log, dark inside.",
                     restoredText: "A thousand fireflies pour out of the hollow and drift into the trees.",
                     variants: [
                        LandmarkVariant(id: "gold", name: "Golden Swarm", blurb: "Classic warm fireflies.", hex: 0xFFE07A),
                        LandmarkVariant(id: "green", name: "Green Swarm", blurb: "Minty, glimmering light.", hex: 0xB5F2A0),
                     ],
                     x: 1200, y: 460, companion: "glimmer"),
            Landmark(id: "standingStones", name: "Standing Stones", area: "ridge",
                     blurb: "Three old stones with faded carvings.",
                     restoredText: "The carvings glow, tracing the shapes of constellations.",
                     variants: [
                        LandmarkVariant(id: "azure", name: "Azure Runes", blurb: "Sky-blue glow.", hex: 0x7FC8FF),
                        LandmarkVariant(id: "violet", name: "Violet Runes", blurb: "Twilight glow.", hex: 0xB79CFF),
                     ],
                     x: 1330, y: 420, companion: "nox"),
            Landmark(id: "moonflowers", name: "Moonflower Garden", area: "ridge",
                     blurb: "Closed buds that wait for something.",
                     restoredText: "The moonflowers open all at once, like a held breath let go.",
                     variants: [
                        LandmarkVariant(id: "silver", name: "Silver Blooms", blurb: "Pale and luminous.", hex: 0xE6ECFF),
                        LandmarkVariant(id: "indigo", name: "Indigo Blooms", blurb: "Deep and velvety.", hex: 0x6A6FD8),
                     ],
                     x: 1450, y: 455),
            Landmark(id: "starShrine", name: "The Star Shrine", area: "ridge",
                     blurb: "A hidden arch at the very top of the ridge, shown on an old map.",
                     restoredText: "A small star settles inside the arch, and the whole grove hums.",
                     variants: [
                        LandmarkVariant(id: "dawn", name: "Dawn Star", blurb: "Rosy gold.", hex: 0xFFC2A0),
                        LandmarkVariant(id: "dusk", name: "Dusk Star", blurb: "Lilac silver.", hex: 0xDCCFFF),
                     ],
                     x: 1550, y: 395, requiresCurio: "starMap"),
        ],
        companions: [
            Companion(id: "tansy", name: "Tansy", species: "Fox spirit",
                      blurb: "A curious fox with a tail like a dandelion clock. She followed the smoke.",
                      homeLandmark: nil, arrivesWithChapter: "ch3",
                      memories: [3: "Tansy curled up beside the hearth and fell asleep with her nose on Ember's foot.",
                                 6: "Tansy admitted she used to live here, long ago, before the fire went out.",
                                 10: "Tansy brought a single warm coal from somewhere far away and set it in the hearth. \"For luck.\""],
                      gifts: [3: .cosmetic("knitScarf"), 6: .seeds(40), 10: .cosmetic("rose")]),
            Companion(id: "mosslings", name: "The Mosslings", species: "Snail family",
                      blurb: "Five tiny snails who live in the mushroom ring. They never hurry.",
                      homeLandmark: "mushroomRing", arrivesWithChapter: nil,
                      memories: [3: "The Mosslings left a silvery trail that spelled, very slowly, \"hi\".",
                                 6: "The smallest Mossling rode on Ember's head for a whole afternoon.",
                                 10: "The Mosslings wove a crown of tiny flowers. It took them a month."],
                      gifts: [3: .seeds(25), 6: .cosmetic("flowerCrown"), 10: .seeds(80)]),
            Companion(id: "pebble", name: "Pebble", species: "Pond frog",
                      blurb: "A round green frog who is certain he is a great singer.",
                      homeLandmark: "lilyPond", arrivesWithChapter: nil,
                      memories: [3: "Pebble performed his finest song. Ember clapped politely.",
                                 6: "Pebble showed Ember the best lily pad for watching dragonflies.",
                                 10: "Pebble wrote a song about Ember. It has eleven verses."],
                      gifts: [3: .seeds(30), 6: .decoration("steppingStones"), 10: .seeds(80)]),
            Companion(id: "wren", name: "Wren", species: "Little brown bird",
                      blurb: "A busy bird who keeps the water wheel free of twigs.",
                      homeLandmark: "waterWheel", arrivesWithChapter: nil,
                      memories: [3: "Wren taught Ember three new whistles.",
                                 6: "Wren brought news from beyond the ridge: the sky is wider there.",
                                 10: "Wren built a nest right above the hearth, so she'd never be far."],
                      gifts: [3: .cosmetic("bellCollar"), 6: .seeds(40), 10: .decoration("birdhouse")]),
            Companion(id: "hoot", name: "Old Hoot", species: "Owl",
                      blurb: "The oak's keeper. Wise, a little deaf, very fond of naps.",
                      homeLandmark: "oldOak", arrivesWithChapter: nil,
                      memories: [3: "Old Hoot told a story about the grove's first spark. He fell asleep halfway.",
                                 6: "Old Hoot remembered the rest: the first spark was a promise, kept every day.",
                                 10: "Old Hoot named Ember a Keeper of the Grove, then took a very long nap."],
                      gifts: [3: .seeds(30), 6: .cosmetic("roundGlasses"), 10: .seeds(100)]),
            Companion(id: "glimmer", name: "Glimmer", species: "Firefly queen",
                      blurb: "Tiny, bright, and very much in charge.",
                      homeLandmark: "fireflyHollow", arrivesWithChapter: nil,
                      memories: [3: "Glimmer's court performed a light show in Ember's honor.",
                                 6: "Glimmer confessed that fireflies learned to glow by watching Ember's kind.",
                                 10: "Glimmer gave Ember a firefly to keep. It sleeps in the moss cap."],
                      gifts: [3: .seeds(35), 6: .decoration("fairyLights"), 10: .seeds(100)]),
            Companion(id: "nox", name: "Nox", species: "Star hare",
                      blurb: "A silver hare who only comes out when the stars do.",
                      homeLandmark: "standingStones", arrivesWithChapter: nil,
                      memories: [3: "Nox showed Ember how to find the North Lantern in the sky.",
                                 6: "Nox and Ember counted shooting stars until they lost count.",
                                 10: "Nox said Ember's flame is visible from the stars. They're watching, kindly."],
                      gifts: [3: .cosmetic("starCirclet"), 6: .seeds(50), 10: .seeds(120)]),
        ],
        cosmetics: [
            Cosmetic(id: "acornCap", name: "Acorn Cap", slot: .head, unlock: .level(3), blurb: "Snug, sturdy, slightly too big."),
            Cosmetic(id: "mushroomHat", name: "Toadstool Hat", slot: .head, unlock: .seeds(60), blurb: "Borrowed from the Mosslings. Permanently."),
            Cosmetic(id: "flowerCrown", name: "Flower Crown", slot: .head, unlock: .gift(companion: "mosslings"), blurb: "Woven very, very slowly."),
            Cosmetic(id: "starCirclet", name: "Star Circlet", slot: .head, unlock: .gift(companion: "nox"), blurb: "A thin band holding a fallen star."),
            Cosmetic(id: "leafScarf", name: "Leaf Scarf", slot: .neck, unlock: .level(6), blurb: "Two leaves, carefully knotted."),
            Cosmetic(id: "knitScarf", name: "Knit Scarf", slot: .neck, unlock: .gift(companion: "tansy"), blurb: "Smells faintly of woodsmoke and fox."),
            Cosmetic(id: "bellCollar", name: "Bell Collar", slot: .neck, unlock: .gift(companion: "wren"), blurb: "Jingles at every hop."),
            Cosmetic(id: "roundGlasses", name: "Reading Glasses", slot: .face, unlock: .seeds(40), blurb: "For serious study and looking wise."),
            Cosmetic(id: "amber", name: "Amber Flame", slot: .flame, unlock: .starter, blurb: "Ember's first flame."),
            Cosmetic(id: "gold", name: "Hearth Gold", slot: .flame, unlock: .path(.hearth), blurb: "Steady as a home fire."),
            Cosmetic(id: "jade", name: "Jadeleaf", slot: .flame, unlock: .path(.bloom), blurb: "The color of new leaves."),
            Cosmetic(id: "azure", name: "Azure Star", slot: .flame, unlock: .path(.starlight), blurb: "Borrowed from the night."),
            Cosmetic(id: "rose", name: "Rosefire", slot: .flame, unlock: .gift(companion: "tansy"), blurb: "Tansy's lucky coal."),
            Cosmetic(id: "violet", name: "Moonviolet", slot: .flame, unlock: .curios(12), blurb: "Kindled by a full collection."),
        ],
        decorations: [
            Decoration(id: "steppingStones", name: "Stepping Stones", blurb: "A winding path to the hearth.", cost: 30),
            Decoration(id: "toadstoolStools", name: "Toadstool Stools", blurb: "Seats for visiting friends.", cost: 35),
            Decoration(id: "windChimes", name: "Wind Chimes", blurb: "Hollow reeds that hum in the breeze.", cost: 45),
            Decoration(id: "birdhouse", name: "Birdhouse", blurb: "A cozy box on a post.", cost: 50),
            Decoration(id: "paperLanterns", name: "Paper Lanterns", blurb: "A string of warm lanterns over the clearing.", cost: 60),
            Decoration(id: "fairyLights", name: "Firefly Lights", blurb: "Little jars of borrowed starlight.", cost: 80),
        ],
        curios: [
            Curio(id: "acornTop", name: "Polished Acorn", blurb: "Smooth as a river stone, warm as a pocket.", symbol: "seal.fill", area: "clearing"),
            Curio(id: "clover", name: "Four-Leaf Clover", blurb: "Lucky, obviously.", symbol: "leaf.fill", area: "clearing"),
            Curio(id: "emberGlass", name: "Ember Glass", blurb: "A shard of glass that holds a tiny glow.", symbol: "flame.fill", area: "clearing"),
            Curio(id: "tinyBell", name: "Tiny Brass Bell", blurb: "Rings in a key no one has heard before.", symbol: "bell.fill", area: "clearing"),
            Curio(id: "pressedViolet", name: "Pressed Violet", blurb: "Tucked into the hearthstones, long ago.", symbol: "camera.macro", area: "clearing"),
            Curio(id: "riverGlass", name: "River Glass", blurb: "Sea-green and frosted by the brook.", symbol: "drop.fill", area: "brook"),
            Curio(id: "wishingPebble", name: "Wishing Pebble", blurb: "Perfectly round, with a hole in the middle.", symbol: "circle.fill", area: "brook"),
            Curio(id: "kingfisherFeather", name: "Kingfisher Feather", blurb: "Bluer than anything has a right to be.", symbol: "bird.fill", area: "brook"),
            Curio(id: "ladybugCharm", name: "Ladybug Charm", blurb: "A tiny carved ladybug. It might be real.", symbol: "ladybug.fill", area: "brook"),
            Curio(id: "oldKey", name: "Old Iron Key", blurb: "It fits nothing in the grove. Yet.", symbol: "key.fill", area: "oak"),
            Curio(id: "fireflyJar", name: "Firefly Jar", blurb: "Empty, but still faintly warm.", symbol: "lightbulb.fill", area: "oak"),
            Curio(id: "unsentLetter", name: "Unsent Letter", blurb: "\"Dear Grove, I'll come back. I promise.\"", symbol: "envelope.fill", area: "oak"),
            Curio(id: "mapleSeed", name: "Maple Spinner", blurb: "Twirls all the way down every time.", symbol: "wind", area: "oak"),
            Curio(id: "moonstone", name: "Moonstone", blurb: "Glows a little brighter when you're focusing.", symbol: "moon.fill", area: "ridge"),
            Curio(id: "starMap", name: "Star Map", blurb: "A faded map with one star circled, at the top of the ridge.", symbol: "map.fill", area: "ridge"),
            Curio(id: "cometDust", name: "Comet Dust", blurb: "A pinch of sparkle in a seed pod.", symbol: "sparkles", area: "ridge"),
            Curio(id: "musicBox", name: "Tiny Music Box", blurb: "Plays the first four notes of a lullaby.", symbol: "music.note", area: "ridge"),
        ],
        chapters: [
            Chapter(id: "ch1", number: 1, title: "The Cold Hearth", trigger: .start, pages: [
                "Once, the grove was warm. Fireflies lit the paths, the brook sang, and every creature knew the way home by the glow of the hearth.",
                "Then the fire went out. No one quite remembers why. The frost crept in, and one by one the creatures drifted away.",
                "But in the ashes, something small is still glowing. It blinks, yawns, and looks up at you.",
                "Its name is {name}. And it's been waiting for someone to sit with it a while.",
            ]),
            Chapter(id: "ch2", number: 2, title: "A Spark Returns", trigger: .firstSession, pages: [
                "While you worked, {name} worked too, gathering twigs and breathing on the old coals.",
                "Now the hearth is lit. It's a small fire, but it's a real one.",
                "Somewhere in the dark, the grove notices.",
            ]),
            Chapter(id: "ch3", number: 3, title: "Footprints in the Frost", trigger: .firstRestoration, pages: [
                "The morning after the first restoration, {name} finds a line of small paw prints leading to the hearth.",
                "A fox with a dandelion-clock tail is sitting in the warmth like she owns it. \"I'm Tansy,\" she says. \"I saw the smoke.\"",
                "\"If you're bringing the grove back,\" she adds, \"I'd like to watch.\"",
            ]),
            Chapter(id: "ch4", number: 4, title: "The Brook Remembers", trigger: .areaUnlocked("brook"), pages: [
                "The frost east of the clearing has thinned enough to walk through.",
                "Beyond it, a brook lies still, as if holding its breath. {name} dips a foot in. Ice cracks, just a little.",
                "Tansy says the brook used to sing. Perhaps it could again.",
            ]),
            Chapter(id: "ch5", number: 5, title: "The Shape of a Flame", trigger: .pathChosen, pages: [
                "{name} has been changing. Slowly, the way a seed becomes a sprout without anyone catching it in the act.",
                "Today the change is impossible to miss. {name} stands a little taller, and the flame inside has found its own shape.",
                "Tansy circles twice, sniffs, and decides she approves.",
            ]),
            Chapter(id: "ch6", number: 6, title: "The Old Oak Wakes", trigger: .landmark("oldOak"), pages: [
                "The Old Oak's leaves came back all at once, with a sound like a thousand pages turning.",
                "From a hollow high in the trunk, an owl blinks down. \"Ah,\" says Old Hoot. \"A Keeper. It's been a while.\"",
                "\"The fire didn't go out on its own, you know,\" he adds, and then, infuriatingly, falls asleep.",
            ]),
            Chapter(id: "ch7", number: 7, title: "Beyond the Ridge", trigger: .areaUnlocked("ridge"), pages: [
                "Past the oak the land rises into a high meadow, close to the sky.",
                "At night the stars here are so bright that {name}'s flame flickers back at them, like it's answering.",
                "Old Hoot, awake for once, says the first Keepers came from up here. Somewhere there's a map.",
            ]),
            Chapter(id: "ch8", number: 8, title: "The Star Map", trigger: .curio("starMap"), pages: [
                "Tucked under a stone, wrapped in waxed leaves: a map of the grove, drawn long ago.",
                "Every place you've restored is on it. So is one more, a small arch at the very top of the ridge, with a single star drawn inside.",
                "Beside it, in tiny handwriting: \"Where the promise is kept.\"",
            ]),
            Chapter(id: "ch9", number: 9, title: "A Grove Rekindled", trigger: .allRestored, pages: [
                "Every lantern is lit. The brook sings, the oak rustles, and the ridge glitters under its stars.",
                "Old Hoot finally finishes his story: the fire went out because no one tended it. Not because of a curse, just forgetting.",
                "\"And it came back,\" says Tansy, \"because someone remembered. A little, every day.\"",
                "{name} leans against you, warm and bright. The grove will keep growing. So will you.",
            ]),
        ],
        stages: [
            EvolutionStage(index: 0, minLevel: 1, path: nil, name: "Spark", blurb: "A tiny ember-spirit, newly woken. Small, warm, curious about everything."),
            EvolutionStage(index: 1, minLevel: 4, path: nil, name: "Kindle", blurb: "Bigger and braver. The sprout on its cap has grown a second leaf."),
            EvolutionStage(index: 2, minLevel: 8, path: .hearth, name: "Hearthling", blurb: "Its flame now burns on top for all to see. Friends gather wherever it sits."),
            EvolutionStage(index: 3, minLevel: 15, path: .hearth, name: "Hearthkeeper", blurb: "Flame-tufted and steady. The grove feels warmer just because it's there."),
            EvolutionStage(index: 4, minLevel: 25, path: .hearth, name: "Grove Hearth", blurb: "A living hearth. Embers drift around it like fireflies."),
            EvolutionStage(index: 2, minLevel: 8, path: .bloom, name: "Bloomling", blurb: "Leafy ears and a budding flower. Plants lean toward it like it's the sun."),
            EvolutionStage(index: 3, minLevel: 15, path: .bloom, name: "Bloomwarden", blurb: "Flowers open wherever it naps. Creatures trust it instantly."),
            EvolutionStage(index: 4, minLevel: 25, path: .bloom, name: "Verdant Heart", blurb: "A walking spring. Butterflies follow it everywhere."),
            EvolutionStage(index: 2, minLevel: 8, path: .starlight, name: "Glimmerling", blurb: "Gauzy wings and starry antennae. It hums when the stars come out."),
            EvolutionStage(index: 3, minLevel: 15, path: .starlight, name: "Starwanderer", blurb: "Its wings catch moonlight. It always seems to know where secrets are."),
            EvolutionStage(index: 4, minLevel: 25, path: .starlight, name: "Lantern of the Sky", blurb: "Tiny stars orbit it. Travelers could find their way home by its glow."),
        ],
        abilities: [
            Ability(id: "warmGlow", name: "Warm Glow", blurb: "Every focused minute becomes Glow.", stage: 0, path: nil),
            Ability(id: "emberSense", name: "Ember Sense", blurb: "+5% chance to make a discovery.", stage: 1, path: nil),
            Ability(id: "steadyFlame", name: "Steady Flame", blurb: "+10% Seeds from sessions.", stage: 2, path: .hearth),
            Ability(id: "hearthSong", name: "Hearth Song", blurb: "Friends grow close 25% faster.", stage: 3, path: .hearth),
            Ability(id: "everflame", name: "Everflame", blurb: "+10% Glow from every session.", stage: 4, path: .hearth),
            Ability(id: "greenThumb", name: "Green Thumb", blurb: "Friends grow close 25% faster.", stage: 2, path: .bloom),
            Ability(id: "gentleRain", name: "Gentle Rain", blurb: "+15% Seeds from sessions.", stage: 3, path: .bloom),
            Ability(id: "evergreen", name: "Evergreen", blurb: "+10% Glow from every session.", stage: 4, path: .bloom),
            Ability(id: "wayfinder", name: "Wayfinder", blurb: "+10% chance to make a discovery.", stage: 2, path: .starlight),
            Ability(id: "nightSight", name: "Night Sight", blurb: "Discoveries can happen in sessions of 5+ minutes.", stage: 3, path: .starlight),
            Ability(id: "astralTide", name: "Astral Tide", blurb: "+10% Glow from every session.", stage: 4, path: .starlight),
        ],
        achievements: [
            Achievement(id: "firstSpark", title: "First Spark", blurb: "Complete your first focus session.", symbol: "flame.fill"),
            Achievement(id: "hourOfGlow", title: "An Hour of Glow", blurb: "Focus for 1 hour in total.", symbol: "clock.fill"),
            Achievement(id: "tenHours", title: "Kindled", blurb: "Focus for 10 hours in total.", symbol: "flame.circle.fill"),
            Achievement(id: "fiftyHours", title: "Bonfire", blurb: "Focus for 50 hours in total.", symbol: "sun.max.fill"),
            Achievement(id: "hundredHours", title: "Eternal Flame", blurb: "Focus for 100 hours in total.", symbol: "star.circle.fill"),
            Achievement(id: "deepDive", title: "Deep Dive", blurb: "Focus for 60 minutes in one session.", symbol: "water.waves"),
            Achievement(id: "earlyBird", title: "Early Bird", blurb: "Start a session before 8 AM.", symbol: "sunrise.fill"),
            Achievement(id: "nightOwl", title: "Night Owl", blurb: "Finish a session after 10 PM.", symbol: "moon.stars.fill"),
            Achievement(id: "wellRounded", title: "Well Rounded", blurb: "Focus in four different categories.", symbol: "circle.grid.2x2.fill"),
            Achievement(id: "steadyWeek", title: "Steady Week", blurb: "Focus on 5 different days in one week.", symbol: "calendar"),
            Achievement(id: "pathfinder", title: "Pathfinder", blurb: "Choose Ember's evolution path.", symbol: "arrow.triangle.branch"),
            Achievement(id: "elder", title: "Fully Grown", blurb: "Reach Ember's final form.", symbol: "crown.fill"),
            Achievement(id: "restorer", title: "Restorer", blurb: "Restore 6 places in the grove.", symbol: "hammer.fill"),
            Achievement(id: "explorer", title: "Explorer", blurb: "Unlock every area of the grove.", symbol: "map.fill"),
            Achievement(id: "trueFriend", title: "True Friend", blurb: "Reach 10 hearts with a companion.", symbol: "heart.fill"),
            Achievement(id: "collector", title: "Collector", blurb: "Discover 12 curios.", symbol: "archivebox.fill"),
            Achievement(id: "rekindled", title: "Grove Rekindled", blurb: "Restore every place in the grove.", symbol: "tree.fill"),
        ],
        quests: [
            QuestTemplate(id: "d.focus25", cadence: .daily, title: "Focus for 25 minutes", metric: .minutes, target: 25, seeds: 10, glow: 30),
            QuestTemplate(id: "d.focus60", cadence: .daily, title: "Focus for an hour", metric: .minutes, target: 60, seeds: 20, glow: 50),
            QuestTemplate(id: "d.twoSessions", cadence: .daily, title: "Complete 2 sessions", metric: .sessions, target: 2, seeds: 12, glow: 30),
            QuestTemplate(id: "d.reading", cadence: .daily, title: "Read for 15 minutes", metric: .categoryMinutes(.reading), target: 15, seeds: 12, glow: 30),
            QuestTemplate(id: "d.deep", cadence: .daily, title: "One session of 45+ minutes", metric: .longestSession, target: 45, seeds: 20, glow: 50),
            QuestTemplate(id: "d.morning", cadence: .daily, title: "Start a session before noon", metric: .startedBeforeNoon, target: 1, seeds: 10, glow: 25),
            QuestTemplate(id: "d.study", cadence: .daily, title: "Study for 30 minutes", metric: .categoryMinutes(.studying), target: 30, seeds: 14, glow: 35),
            QuestTemplate(id: "w.threeHours", cadence: .weekly, title: "Focus for 3 hours this week", metric: .minutes, target: 180, seeds: 50, glow: 120),
            QuestTemplate(id: "w.fourDays", cadence: .weekly, title: "Focus on 4 different days", metric: .distinctDays, target: 4, seeds: 45, glow: 100),
            QuestTemplate(id: "w.categories", cadence: .weekly, title: "Focus in 3 different categories", metric: .distinctCategories, target: 3, seeds: 40, glow: 90),
            QuestTemplate(id: "w.tenSessions", cadence: .weekly, title: "Complete 10 sessions", metric: .sessions, target: 10, seeds: 50, glow: 120),
        ],
        renewalMilestones: [45, 120, 240, 400, 600, 850, 1150, 1500, 1900, 2350, 2850, 3400]
    )
}
