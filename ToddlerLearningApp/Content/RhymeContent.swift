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
//  representative excerpt of the traditional words, and not the traditional
//  words at all where the recording differs. That includes the verses that
//  change by a single word: Ten in the Bed counts down from ten, If You're
//  Happy has four actions, Rain Rain asks after six people. The pack's Happy
//  Birthday sings "Happy birthday, happy birthday" where the traditional line
//  has a name, its Muffin Man says "that lives on Drury Lane", and its
//  B-I-N-G-O goes straight from four letters to two. The words people know are
//  a guide to what to listen for, never a substitute for listening.
//
//  The rhyme screen highlights the line being sung from measured cues (see
//  `RhymeCues`), and those are aligned against these lines, so a verse the
//  recording sings but this list omits can never light up. A verse that is
//  sung twice through is written once; the cues revisit it.
//  tools/gen_rhyme_cues.py reads the lyrics straight out of this file, reports
//  how much of each recording they account for, and stamps each cue file with
//  a digest of the words it was aligned against. Re-run it after editing any
//  line here: a cue file made for other lyrics highlights the wrong lines.
//
//  👏 stands for the clap that replaces a letter in B-I-N-G-O. A pre-reader
//  knows it on sight, VoiceOver reads it as "clapping hands", and it has no
//  letters in it, so the cue aligner leaves it out of its matching.
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
                "And one fell out.",
                "There were nine in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out.",
                "There were eight in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out.",
                "There were seven in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out.",
                "There were six in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out.",
                "There were five in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out.",
                "There were four in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out.",
                "There were three in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out.",
                "There were two in the bed,",
                "And the little one said,",
                "\"Roll over, roll over!\"",
                "So they all rolled over,",
                "And one fell out.",
                "There was one in the bed,",
                "And the little one said,",
                "\"Good night!\""
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
                "And one for the dame,",
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
                "And Bingo was his name-o.",
                "There was a farmer had a dog,",
                "And Bingo was his name-o.",
                "👏-I-N-G-O! 👏-I-N-G-O! 👏-I-N-G-O!",
                "And Bingo was his name-o.",
                "There was a farmer had a dog,",
                "And Bingo was his name-o.",
                "👏-👏-👏-G-O! 👏-👏-👏-G-O! 👏-👏-👏-G-O!",
                "And Bingo was his name-o.",
                "There was a farmer had a dog,",
                "And Bingo was his name-o.",
                "👏-👏-👏-👏-O! 👏-👏-👏-👏-O! 👏-👏-👏-👏-O!",
                "And Bingo was his name-o.",
                "There was a farmer had a dog,",
                "And Bingo was his name-o.",
                "👏-👏-👏-👏-👏! 👏-👏-👏-👏-👏! 👏-👏-👏-👏-👏!",
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
                "Just tip me over and pour me out!"
            ],
            audioFileName: "imALittleTeapot.m4a",
            emoji: "🫖",
            colorIndex: 2,
            linkage: .letter("T")
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
            id: "rain-rain-go-away",
            title: "Rain, Rain, Go Away",
            lines: [
                "Rain, rain, go away,",
                "Come again another day.",
                "Daddy wants to play,",
                "Rain, rain, go away.",
                "Rain, rain, go away,",
                "Come again another day.",
                "Mommy wants to play,",
                "Rain, rain, go away.",
                "Rain, rain, go away,",
                "Come again another day.",
                "Brother wants to play,",
                "Rain, rain, go away.",
                "Rain, rain, go away,",
                "Come again another day.",
                "Sister wants to play,",
                "Rain, rain, go away.",
                "Rain, rain, go away,",
                "Come again another day.",
                "Baby wants to play,",
                "Rain, rain, go away.",
                "Rain, rain, go away,",
                "Come again another day.",
                "All the family wants to play,",
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
                "If you're happy and you know it, clap your hands!",
                "If you're happy and you know it, stamp your feet!",
                "If you're happy and you know it, stamp your feet!",
                "If you're happy and you know it, and you really want to show it,",
                "If you're happy and you know it, stamp your feet!",
                "If you're happy and you know it, snap your fingers!",
                "If you're happy and you know it, snap your fingers!",
                "If you're happy and you know it, and you really want to show it,",
                "If you're happy and you know it, snap your fingers!",
                "If you're happy and you know it, shout hooray!",
                "If you're happy and you know it, shout hooray!",
                "If you're happy and you know it, and you really want to show it,",
                "If you're happy and you know it, shout hooray!"
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
                "Mother called the doctor and the doctor said,",
                "\"No more monkeys jumping on the bed!\"",
                "Four little monkeys jumping on the bed,",
                "One fell off and bumped his head.",
                "Mother called the doctor and the doctor said,",
                "\"No more monkeys jumping on the bed!\"",
                "Three little monkeys jumping on the bed,",
                "One fell off and bumped his head.",
                "Mother called the doctor and the doctor said,",
                "\"No more monkeys jumping on the bed!\"",
                "Two little monkeys jumping on the bed,",
                "One fell off and bumped his head.",
                "Mother called the doctor and the doctor said,",
                "\"No more monkeys jumping on the bed!\"",
                "One little monkey jumping on the bed,",
                "He fell off and bumped his head.",
                "Mother called the doctor and the doctor said,",
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
                "Here I am, here I am, how do you do?",
                "Brother finger, Brother finger, where are you?",
                "Here I am, here I am, how do you do?",
                "Sister finger, Sister finger, where are you?",
                "Here I am, here I am, how do you do?",
                "Baby finger, Baby finger, where are you?",
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
                "Well, we'll all go out to meet her when she comes,",
                "Well, we'll all go out to meet her when she comes,",
                "Well, we'll all go out to meet her,",
                "Yes, we'll all go out to meet her,",
                "Yes, we'll all go out to meet her when she comes.",
                "Singing aye, aye, yippee, yippee aye!",
                "Singing aye, aye, yippee, yippee aye!",
                "She'll be wearing silk pajamas when she comes,",
                "She'll be wearing silk pajamas when she comes,",
                "She'll be wearing pink pajamas,",
                "Wearing pink pajamas,",
                "Wearing pink pajamas when she comes.",
                "Singing aye, aye, yippee, yippee aye!",
                "Singing aye, aye, yippee, yippee aye!",
                "Well, she'll be coming round the mountain when she comes,",
                "She'll be coming round the mountain when she comes,",
                "She'll be coming round the mountain,",
                "Coming round the mountain,",
                "Coming round the mountain when she comes."
            ],
            audioFileName: "shellBeComingAroundTheMountain.m4a",
            emoji: "🚂",
            colorIndex: 3,
            linkage: .letter("S")
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
                "Do you know the muffin man,",
                "The muffin man, the muffin man?",
                "Do you know the muffin man",
                "That lives on Drury Lane?",
                "Oh, yes, I know the muffin man,",
                "The muffin man, the muffin man.",
                "Yes, I know the muffin man",
                "That lives on Drury Lane."
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
                "Happy birthday, happy birthday,",
                "Happy birthday to you!"
            ],
            audioFileName: "happyBirthday.m4a",
            emoji: "🎂",
            colorIndex: 6,
            linkage: .letter("H")
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
