//
//  RhymeContent.swift
//  ToddlerLearningApp
//
//  A curated set of traditional, public-domain nursery rhymes — mirrors
//  AlphabetContent/NumberContent's shape. Roughly a third are tied to a
//  specific letter or number via `RhymeLinkage`, which is what Learn
//  Letters/Learn Numbers query to offer a "hear a rhyme" affordance for the
//  item currently on screen; the rest are general sing-alongs with no tie-in.
//
//  Audio is real sung recordings — see Resources/RhymeAudio and
//  RhymeAudioService. `audioFileName` names a file there and is
//  case-sensitive. The recordings came from a licensed nursery-rhyme pack
//  (2026-09-16), replacing an earlier text-to-speech placeholder — see the
//  `rhyme-audio-sourcing` project memory for why that placeholder existed.
//
//  What ships is mono 64kbps AAC: the pack's own stereo 128kbps mp3s are more
//  than a sing-along needs through a phone speaker, and at 38 minutes of audio
//  they were 34MB of a 57MB app. The untouched originals are kept in a
//  `RhymeAudioOriginals/` folder *beside* the repo rather than inside it —
//  they are the masters to re-cut from if these ever need redoing, but they
//  are deliberately out of version control, so only the audio the app actually
//  plays is ever committed.
//
//  `lines` is what that recording actually sings, verse for verse — not a
//  representative excerpt of the traditional words. The rhyme screen
//  highlights the line being sung from measured cues (see `RhymeCues`), and
//  those are aligned against these lines, so a verse the recording sings but
//  this list omits can never light up. tools/gen_rhyme_cues.py reads the
//  lyrics straight out of this file and reports how much of each recording
//  they account for; re-run it after editing any line here.
//

import Foundation

enum RhymeContent {

    static let rhymes: [Rhyme] = [
        Rhyme(
            id: "twinkle-twinkle",
            title: "Twinkle, Twinkle, Little Star",
            lines: [
                "Twinkle, twinkle, little star,",
                "How I wonder what you are.",
                "Up above the world so high,",
                "Like a diamond in the sky.",
                "When the blazing sun is gone,",
                "When he nothing shines upon,",
                "Then you show your little light,",
                "Twinkle, twinkle, all the night.",
                "Then the traveller in the dark",
                "Thanks you for your tiny spark;",
                "He could not see which way to go,",
                "If you did not twinkle so.",
                "In the dark blue sky you keep,",
                "And often through my curtains peep,",
                "For you never shut your eye",
                "Till the sun is in the sky.",
                "As your bright and tiny spark",
                "Lights the traveller in the dark,",
                "Though I know not what you are,"
            ],
            audioFileName: "twinkleTwinkle.m4a",
            emoji: "⭐️",
            colorIndex: 6,
            linkage: .general
        ),
        Rhyme(
            id: "hickory-dickory-dock",
            title: "Hickory Dickory Dock",
            lines: [
                "Hickory dickory dock,",
                "The mouse ran up the clock.",
                "The clock struck one,",
                "The mouse ran down,",
                "Hickory dickory dock."
            ],
            audioFileName: "hickoryDickoryDock.m4a",
            emoji: "🐭",
            colorIndex: 3,
            linkage: .general
        ),
        Rhyme(
            id: "ten-in-the-bed",
            title: "Ten in the Bed",
            lines: [
                "There were ten in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out."
            ],
            audioFileName: "tenInTheBed.m4a",
            emoji: "🛏️",
            colorIndex: 2,
            linkage: .number(10)
        ),
        Rhyme(
            id: "baa-baa-black-sheep",
            title: "Baa, Baa, Black Sheep",
            lines: [
                "Baa, baa, black sheep,",
                "Have you any wool?",
                "Yes sir, yes sir,",
                "Three bags full.",
                "One for the master,",
                "One for the dame,",
                "And one for the little boy",
                "Who lives down the lane."
            ],
            audioFileName: "BaaBaaBlackSheep.m4a",
            emoji: "🐑",
            colorIndex: 1,
            linkage: .letter("B")
        ),
        Rhyme(
            id: "hush-little-baby",
            title: "Hush, Little Baby",
            lines: [
                "Hush, little baby, don't say a word,",
                "Papa's gonna buy you a mockingbird.",
                "If that mockingbird don't sing,",
                "Papa's gonna buy you a diamond ring.",
                "If that diamond ring turns brass,",
                "Papa's gonna buy you a looking glass.",
                "And if that looking glass gets broke,",
                "Papa's gonna buy you a billy goat.",
                "If that billy goat won't pull,",
                "Papa's gonna buy you a cart and bull.",
                "If that cart and bull turns over,",
                "Papa's gonna buy you a dog named Rover.",
                "If that dog named Rover won't bark,",
                "Papa's gonna buy you a horse and cart.",
                "If that horse and cart falls down,",
                "You'll still be the sweetest little baby in town."
            ],
            audioFileName: "hushLittleBaby.m4a",
            emoji: "👶",
            colorIndex: 4,
            linkage: .general
        ),
        Rhyme(
            id: "bingo",
            title: "B-I-N-G-O",
            lines: [
                "There was a farmer had a dog,",
                "And Bingo was his name-o.",
                "B-I-N-G-O! B-I-N-G-O! B-I-N-G-O!",
                "And Bingo was his name-o."
            ],
            audioFileName: "bingoS.m4a",
            emoji: "🐶",
            colorIndex: 3,
            linkage: .letter("B")
        ),
        Rhyme(
            id: "im-a-little-teapot",
            title: "I'm a Little Teapot",
            lines: [
                "I'm a little teapot, short and stout,",
                "Here is my handle, here is my spout.",
                "When I get all steamed up, hear me shout,",
                "Tip me over and pour me out!"
            ],
            audioFileName: "imALittleTeapot.m4a",
            emoji: "🫖",
            colorIndex: 2,
            linkage: .letter("T")
        ),
        Rhyme(
            id: "little-snowflake",
            title: "Little Snowflake",
            lines: [
                "Snowflake, snowflake, little snowflake,",
                "Little snowflake falling from the sky.",
                "Snowflake, snowflake, little snowflake,",
                "Falling, falling, falling, falling, falling, falling,",
                "Falling on my head.",
                "Snowflake, snowflake, little snowflake,",
                "Little snowflake falling from the sky.",
                "Snowflake, snowflake, little snowflake,",
                "Falling, falling, falling, falling, falling, falling,",
                "Falling on my nose.",
                "Snowflake, snowflake, little snowflake,",
                "Little snowflake falling from the sky.",
                "Snowflake, snowflake, little snowflake,",
                "Falling, falling, falling, falling, falling, falling,",
                "Falling in my hand.",
                "Falling on my head.",
                "Falling on my nose.",
                "Falling in my hand.",
                "Snowflake, snowflake, little snowflake."
            ],
            audioFileName: "littleSnowFlake.m4a",
            emoji: "❄️",
            colorIndex: 4,
            linkage: .general
        ),
        Rhyme(
            id: "ring-a-ring-o-roses",
            title: "Ring a Ring o' Roses",
            lines: [
                "Ring a ring o' roses,",
                "A pocket full of posies,",
                "A-tishoo! A-tishoo!",
                "We all fall down!"
            ],
            audioFileName: "RingARingORoses.m4a",
            emoji: "🌹",
            colorIndex: 6,
            linkage: .general
        ),
        Rhyme(
            id: "pat-a-cake",
            title: "Pat-a-Cake",
            lines: [
                "Pat-a-cake, pat-a-cake, baker's man,",
                "Bake me a cake just as fast as we can.",
                "Pat it and prick it and mark it with B,",
                "Put it in the oven for baby and me.",
                "For baby and me, for baby and me,",
                "Put it in the oven for baby and me."
            ],
            audioFileName: "patACake.m4a",
            emoji: "🍰",
            colorIndex: 0,
            linkage: .general
        ),
        Rhyme(
            id: "rain-rain-go-away",
            title: "Rain, Rain, Go Away",
            lines: [
                "Rain, rain, go away,",
                "Come again another day.",
                "Little one wants to play,",
                "Rain, rain, go away."
            ],
            audioFileName: "rainRainGoAway.m4a",
            emoji: "🌧️",
            colorIndex: 4,
            linkage: .general
        ),
        Rhyme(
            id: "if-youre-happy-and-you-know-it",
            title: "If You're Happy and You Know It",
            lines: [
                "If you're happy and you know it, clap your hands!",
                "If you're happy and you know it, clap your hands!",
                "If you're happy and you know it, and you really want to show it,",
                "If you're happy and you know it, clap your hands!"
            ],
            audioFileName: "ifYoureHappyAndYouKnowIt.m4a",
            emoji: "😊",
            colorIndex: 2,
            linkage: .general
        ),
        Rhyme(
            id: "five-little-monkeys",
            title: "Five Little Monkeys",
            lines: [
                "Five little monkeys jumping on the bed,",
                "One fell off and bumped his head.",
                "Mama called the doctor and the doctor said,",
                "\"No more monkeys jumping on the bed!\""
            ],
            audioFileName: "fiveLittleMonkeys.m4a",
            emoji: "🐒",
            colorIndex: 0,
            linkage: .number(5)
        ),
        Rhyme(
            id: "head-shoulders-knees-and-toes",
            title: "Head, Shoulders, Knees and Toes",
            lines: [
                "Head, shoulders, knees and toes,",
                "Knees and toes!",
                "Head, shoulders, knees and toes,",
                "Knees and toes!",
                "And eyes and ears and mouth and nose,",
                "Head, shoulders, knees and toes,",
                "Knees and toes!"
            ],
            audioFileName: "headAndShoulders.m4a",
            emoji: "🙆",
            colorIndex: 3,
            linkage: .general
        ),
        Rhyme(
            id: "wheels-on-the-bus",
            title: "The Wheels on the Bus",
            lines: [
                "The wheels on the bus go round and round,",
                "Round and round, round and round.",
                "The wheels on the bus go round and round,",
                "All through the town.",
                "The doors on the bus go open and shut,",
                "Open and shut, open and shut.",
                "The doors on the bus go open and shut,",
                "All through the town.",
                "The wipers on the bus go swish, swish, swish,",
                "Swish, swish, swish, swish, swish, swish.",
                "The wipers on the bus go swish, swish, swish,",
                "All through the town.",
                "The baby on the bus goes wah, wah, wah,",
                "Wah, wah, wah, wah, wah, wah.",
                "The baby on the bus goes wah, wah, wah,",
                "All through the town.",
                "The mommy on the bus goes shh, shh, shh,",
                "Shh, shh, shh, shh, shh, shh.",
                "The mommy on the bus goes shh, shh, shh,",
                "All through the town.",
                "The daddy on the bus goes read, read, read,",
                "Read, read, read, read, read, read.",
                "The daddy on the bus goes read, read, read,",
                "All through the town.",
                "The mommy and the daddy say I love you,",
                "I love you, I love you.",
                "The mommy and the daddy say I love you,",
                "All through the town."
            ],
            audioFileName: "wheelsOnTheBus.m4a",
            emoji: "🚌",
            colorIndex: 5,
            linkage: .letter("W")
        ),
        Rhyme(
            id: "finger-family",
            title: "Finger Family",
            lines: [
                "Daddy finger, Daddy finger, where are you?",
                "Here I am, here I am, how do you do?",
                "Mommy finger, Mommy finger, where are you?",
                "Here I am, here I am, how do you do?"
            ],
            audioFileName: "fingerfamily.m4a",
            emoji: "☝️",
            colorIndex: 6,
            linkage: .letter("F")
        ),
        Rhyme(
            id: "teddy-bear-turn-around",
            title: "Teddy Bear, Teddy Bear, Turn Around",
            lines: [
                "Teddy bear, teddy bear, turn around,",
                "Teddy bear, teddy bear, touch the ground.",
                "Teddy bear, teddy bear, jump up high,",
                "Teddy bear, teddy bear, touch the sky.",
                "Teddy bear, teddy bear, take my hand,",
                "Teddy bear, teddy bear, you're my friend.",
                "Teddy bear, teddy bear, I love you,",
                "Teddy bear, teddy bear, this is true.",
                "Teddy bear, teddy bear, turn off the light,",
                "Everybody say shush, shhh!",
                "Teddy bear, teddy bear, say goodnight."
            ],
            audioFileName: "teddyBear.m4a",
            emoji: "🧸",
            colorIndex: 1,
            linkage: .letter("T")
        ),
        Rhyme(
            id: "shes-coming-round-the-mountain",
            title: "She'll Be Coming 'Round the Mountain",
            lines: [
                "She'll be coming round the mountain when she comes,",
                "She'll be coming round the mountain when she comes,",
                "She'll be coming round the mountain,",
                "She'll be coming round the mountain,",
                "She'll be coming round the mountain when she comes.",
                "Singing aye, aye, yippee, yippee aye!",
                "Singing aye, aye, yippee, yippee aye!",
                "She'll be riding six white horses when she comes,",
                "She'll be riding six white horses when she comes,",
                "She'll be riding six white horses,",
                "She'll be riding six white horses,",
                "She'll be riding six white horses when she comes.",
                "Singing aye, aye, yippee, yippee aye!",
                "Singing aye, aye, yippee, yippee aye!",
                "She'll be wearing pink pajamas when she comes,",
                "She'll be wearing pink pajamas when she comes,",
                "She'll be wearing pink pajamas,",
                "She'll be wearing pink pajamas,",
                "She'll be wearing pink pajamas when she comes.",
                "Singing aye, aye, yippee, yippee aye!",
                "Singing aye, aye, yippee, yippee aye!"
            ],
            audioFileName: "shellBeComingAroundTheMountain.m4a",
            emoji: "🚂",
            colorIndex: 3,
            linkage: .letter("S")
        ),
        Rhyme(
            id: "are-you-sleeping-brother-john",
            title: "Are You Sleeping? (Brother John)",
            lines: [
                "Are you sleeping, are you sleeping,",
                "Brother John, Brother John?",
                "Morning bells are ringing, morning bells are ringing,",
                "Ding, dang, dong! Ding, dang, dong!"
            ],
            audioFileName: "areYouSleepingBrotherJohn.m4a",
            emoji: "🔔",
            colorIndex: 4,
            linkage: .letter("A")
        ),
        Rhyme(
            id: "im-a-little-star",
            title: "I'm a Little Star",
            lines: [
                "I'm a little star hanging on a tree,",
                "See the little children dance around me.",
                "Tra la la, tra la la, tra la la, tra la la,",
                "Tra la la, tra la la, tra la la la.",
                "I'm a candy stick hanging on a tree,",
                "See the little children dance around me.",
                "Tra la la, tra la la, tra la la, tra la la,",
                "Tra la la, tra la la, tra la la la.",
                "I'm a pretty angel hanging on a tree,",
                "See the little children dance around me.",
                "Tra la la, tra la la, tra la la, tra la la,",
                "Tra la la, tra la la, tra la la la.",
                "I'm a bright light hanging on a tree,",
                "See the little children dance around me.",
                "Tra la la, tra la la, tra la la, tra la la,",
                "Tra la la, tra la la, tra la la la."
            ],
            audioFileName: "imALittleStar.m4a",
            emoji: "✨",
            colorIndex: 5,
            linkage: .general
        ),
        Rhyme(
            id: "alphabet-song",
            title: "The Alphabet Song",
            lines: [
                "A, B, C, D, E, F, G,",
                "H, I, J, K, L, M, N, O, P,",
                "Q, R, S, T, U, V,",
                "W, X, Y, and Z.",
                "Now I know my A-B-C's,",
                "Next time won't you sing with me?"
            ],
            audioFileName: "alphabet_song.m4a",
            emoji: "🔤",
            colorIndex: 6,
            linkage: .general
        ),
        Rhyme(
            id: "yankee-doodle",
            title: "Yankee Doodle",
            lines: [
                "Yankee Doodle went to town,",
                "Riding on a pony,",
                "Stuck a feather in his cap",
                "And called it macaroni.",
                "Yankee Doodle keep it up,",
                "Yankee Doodle dandy,",
                "Mind the music and the step,",
                "And with the girls be handy.",
                "Father and I went down to camp,",
                "Along with Captain Gooding,",
                "And there we saw the men and boys",
                "As thick as hasty pudding.",
                "There was Captain Washington",
                "Upon a slapping stallion,",
                "And all the men and boys around,",
                "I guess there was a million."
            ],
            audioFileName: "yankeeDoodle.m4a",
            emoji: "🎩",
            colorIndex: 0,
            linkage: .letter("Y")
        ),
        Rhyme(
            id: "clap-clap-clap-your-hands",
            title: "Clap, Clap, Clap Your Hands",
            lines: [
                "Clap, clap, clap your hands,",
                "Clap your hands together.",
                "Shake, shake, shake your hands,",
                "Shake your hands together.",
                "Pound, pound, pound your hands,",
                "Pound your hands together.",
                "Roll, roll, roll your hands,",
                "Roll your hands together.",
                "Pat, pat, pat your face,",
                "Pat your face together."
            ],
            audioFileName: "clapClapClapYourHands.m4a",
            emoji: "👏",
            colorIndex: 2,
            linkage: .letter("C")
        ),
        Rhyme(
            id: "muffin-man",
            title: "The Muffin Man",
            lines: [
                "Oh, do you know the muffin man,",
                "The muffin man, the muffin man?",
                "Oh, do you know the muffin man,",
                "Who lives on Drury Lane?"
            ],
            audioFileName: "muffinMan.m4a",
            emoji: "🧁",
            colorIndex: 1,
            linkage: .letter("M")
        ),
        Rhyme(
            id: "happy-birthday-to-you",
            title: "Happy Birthday to You",
            lines: [
                "Happy birthday to you,",
                "Happy birthday to you,",
                "Happy birthday, dear friend,",
                "Happy birthday to you!"
            ],
            audioFileName: "happyBirthday.m4a",
            emoji: "🎂",
            colorIndex: 6,
            linkage: .letter("H")
        ),
        Rhyme(
            id: "london-bridge-is-falling-down",
            title: "London Bridge Is Falling Down",
            lines: [
                "London Bridge is falling down,",
                "Falling down, falling down.",
                "London Bridge is falling down,",
                "My fair lady.",
                "Build it up with wood and clay,",
                "Wood and clay, wood and clay,",
                "Build it up with wood and clay,",
                "My fair lady.",
                "Wood and clay will wash away,",
                "Wash away, wash away,",
                "Wood and clay will wash away,",
                "My fair lady.",
                "Build it up with bricks and mortar,",
                "Bricks and mortar, bricks and mortar,",
                "Build it up with bricks and mortar,",
                "My fair lady.",
                "Bricks and mortar will not stay,",
                "Will not stay, will not stay,",
                "Bricks and mortar will not stay,",
                "My fair lady.",
                "Build it up with silver and gold,",
                "Silver and gold, silver and gold,",
                "Build it up with silver and gold,",
                "My fair lady."
            ],
            audioFileName: "londonBridgeIsFallingDown.m4a",
            emoji: "🌉",
            colorIndex: 4,
            linkage: .letter("L")
        )
    ]

    private static let index: [String: Rhyme] = Dictionary(
        uniqueKeysWithValues: rhymes.map { ($0.id, $0) }
    )

    static func rhyme(id: String) -> Rhyme? {
        index[id]
    }

    static func rhymes(forLetter letterID: String) -> [Rhyme] {
        rhymes.filter { $0.linkage == .letter(letterID) }
    }

    static func rhymes(forNumber numberID: Int) -> [Rhyme] {
        rhymes.filter { $0.linkage == .number(numberID) }
    }
}
