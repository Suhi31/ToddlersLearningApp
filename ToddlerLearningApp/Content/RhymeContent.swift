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
//  Audio is not bundled yet — see docs/PRODUCT_SPEC.md and the app's
//  RhymeAudioService: `audioFileName` names the resource each rhyme expects
//  once licensed/public-domain recordings are added to Resources/RhymeAudio.
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
                "Twinkle, twinkle, little star,",
                "How I wonder what you are."
            ],
            audioFileName: "twinkle-twinkle.m4a",
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
            audioFileName: "hickory-dickory-dock.m4a",
            emoji: "🐭",
            colorIndex: 3,
            linkage: .general
        ),
        Rhyme(
            id: "this-old-man",
            title: "This Old Man",
            lines: [
                "This old man, he played one,",
                "He played knick-knack on my thumb.",
                "With a knick-knack, paddywhack,",
                "Give a dog a bone,",
                "This old man came rolling home."
            ],
            audioFileName: "this-old-man.m4a",
            emoji: "🎵",
            colorIndex: 1,
            linkage: .general
        ),
        Rhyme(
            id: "row-row-row-your-boat",
            title: "Row, Row, Row Your Boat",
            lines: [
                "Row, row, row your boat,",
                "Gently down the stream.",
                "Merrily, merrily, merrily, merrily,",
                "Life is but a dream."
            ],
            audioFileName: "row-row-row-your-boat.m4a",
            emoji: "🚣",
            colorIndex: 4,
            linkage: .general
        ),
        Rhyme(
            id: "one-two-buckle-my-shoe",
            title: "One, Two, Buckle My Shoe",
            lines: [
                "One, two, buckle my shoe.",
                "Three, four, knock at the door.",
                "Five, six, pick up sticks.",
                "Seven, eight, lay them straight.",
                "Nine, ten, a big fat hen."
            ],
            audioFileName: "one-two-buckle-my-shoe.m4a",
            emoji: "👞",
            colorIndex: 0,
            linkage: .number(1)
        ),
        Rhyme(
            id: "two-little-blackbirds",
            title: "Two Little Blackbirds",
            lines: [
                "Two little blackbirds sitting on a hill,",
                "One named Jack, one named Jill.",
                "Fly away, Jack! Fly away, Jill!",
                "Come back, Jack! Come back, Jill!"
            ],
            audioFileName: "two-little-blackbirds.m4a",
            emoji: "🐦",
            colorIndex: 5,
            linkage: .number(2)
        ),
        Rhyme(
            id: "three-blind-mice",
            title: "Three Blind Mice",
            lines: [
                "Three blind mice, three blind mice,",
                "See how they run, see how they run.",
                "They all ran after the farmer's wife,",
                "Who cut off their tails with a carving knife.",
                "Did you ever see such a thing in your life,",
                "As three blind mice?"
            ],
            audioFileName: "three-blind-mice.m4a",
            emoji: "🐁",
            colorIndex: 2,
            linkage: .number(3)
        ),
        Rhyme(
            id: "five-little-ducks",
            title: "Five Little Ducks",
            lines: [
                "Five little ducks went out one day,",
                "Over the hill and far away.",
                "Mother duck said, \"Quack, quack, quack, quack,\"",
                "But only four little ducks came back."
            ],
            audioFileName: "five-little-ducks.m4a",
            emoji: "🦆",
            colorIndex: 4,
            linkage: .number(5)
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
            audioFileName: "ten-in-the-bed.m4a",
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
            audioFileName: "baa-baa-black-sheep.m4a",
            emoji: "🐑",
            colorIndex: 1,
            linkage: .letter("B")
        ),
        Rhyme(
            id: "itsy-bitsy-spider",
            title: "The Itsy Bitsy Spider",
            lines: [
                "The itsy bitsy spider climbed up the water spout.",
                "Down came the rain and washed the spider out.",
                "Out came the sun and dried up all the rain,",
                "And the itsy bitsy spider climbed up the spout again."
            ],
            audioFileName: "itsy-bitsy-spider.m4a",
            emoji: "🕷️",
            colorIndex: 4,
            linkage: .letter("S")
        ),
        Rhyme(
            id: "little-miss-muffet",
            title: "Little Miss Muffet",
            lines: [
                "Little Miss Muffet sat on a tuffet,",
                "Eating her curds and whey.",
                "Along came a spider,",
                "Who sat down beside her,",
                "And frightened Miss Muffet away."
            ],
            audioFileName: "little-miss-muffet.m4a",
            emoji: "🥣",
            colorIndex: 5,
            linkage: .letter("M")
        ),
        Rhyme(
            id: "jack-and-jill",
            title: "Jack and Jill",
            lines: [
                "Jack and Jill went up the hill,",
                "To fetch a pail of water.",
                "Jack fell down and broke his crown,",
                "And Jill came tumbling after."
            ],
            audioFileName: "jack-and-jill.m4a",
            emoji: "⛰️",
            colorIndex: 2,
            linkage: .letter("J")
        ),
        Rhyme(
            id: "old-macdonald",
            title: "Old MacDonald Had a Farm",
            lines: [
                "Old MacDonald had a farm, E-I-E-I-O,",
                "And on his farm he had a cow, E-I-E-I-O.",
                "With a moo-moo here, and a moo-moo there,",
                "Here a moo, there a moo, everywhere a moo-moo,",
                "Old MacDonald had a farm, E-I-E-I-O."
            ],
            audioFileName: "old-macdonald.m4a",
            emoji: "🚜",
            colorIndex: 0,
            linkage: .letter("O")
        ),
        Rhyme(
            id: "humpty-dumpty",
            title: "Humpty Dumpty",
            lines: [
                "Humpty Dumpty sat on a wall,",
                "Humpty Dumpty had a great fall.",
                "All the king's horses and all the king's men,",
                "Couldn't put Humpty together again."
            ],
            audioFileName: "humpty-dumpty.m4a",
            emoji: "🥚",
            colorIndex: 3,
            linkage: .letter("H")
        ),
        Rhyme(
            id: "pussycat-pussycat",
            title: "Pussycat, Pussycat",
            lines: [
                "Pussycat, pussycat, where have you been?",
                "I've been to London to visit the Queen.",
                "Pussycat, pussycat, what did you there?",
                "I frightened a little mouse under her chair."
            ],
            audioFileName: "pussycat-pussycat.m4a",
            emoji: "🐱",
            colorIndex: 1,
            linkage: .letter("P")
        ),
        Rhyme(
            id: "a-was-an-apple-pie",
            title: "A Was an Apple Pie",
            lines: [
                "A was an apple pie,",
                "B bit it,",
                "C cut it,",
                "D dealt it,",
                "E eat it,",
                "F fought for it."
            ],
            audioFileName: "a-was-an-apple-pie.m4a",
            emoji: "🥧",
            colorIndex: 0,
            linkage: .letter("A")
        ),
        Rhyme(
            id: "cobbler-cobbler",
            title: "Cobbler, Cobbler",
            lines: [
                "Cobbler, cobbler, mend my shoe,",
                "Get it done by half past two.",
                "Stitch it up and stitch it down,",
                "Then I'll give you half a crown."
            ],
            audioFileName: "cobbler-cobbler.m4a",
            emoji: "🧵",
            colorIndex: 2,
            linkage: .letter("C")
        ),
        Rhyme(
            id: "diddle-diddle-dumpling",
            title: "Diddle, Diddle, Dumpling",
            lines: [
                "Diddle, diddle, dumpling, my son John,",
                "Went to bed with his trousers on.",
                "One shoe off, and one shoe on,",
                "Diddle, diddle, dumpling, my son John."
            ],
            audioFileName: "diddle-diddle-dumpling.m4a",
            emoji: "🛌",
            colorIndex: 3,
            linkage: .letter("D")
        ),
        Rhyme(
            id: "fiddle-dee-dee",
            title: "Fiddle-Dee-Dee",
            lines: [
                "Fiddle-dee-dee, fiddle-dee-dee,",
                "The fly has married the bumblebee.",
                "Says the fly, says he,",
                "Will you marry me?"
            ],
            audioFileName: "fiddle-dee-dee.m4a",
            emoji: "🐝",
            colorIndex: 5,
            linkage: .letter("F")
        ),
        Rhyme(
            id: "georgie-porgie",
            title: "Georgie Porgie",
            lines: [
                "Georgie Porgie, pudding and pie,",
                "Kissed the girls and made them cry.",
                "When the boys came out to play,",
                "Georgie Porgie ran away."
            ],
            audioFileName: "georgie-porgie.m4a",
            emoji: "🥧",
            colorIndex: 6,
            linkage: .letter("G")
        ),
        Rhyme(
            id: "little-nut-tree",
            title: "I Had a Little Nut Tree",
            lines: [
                "I had a little nut tree,",
                "Nothing would it bear,",
                "But a silver nutmeg,",
                "And a golden pear."
            ],
            audioFileName: "little-nut-tree.m4a",
            emoji: "🌰",
            colorIndex: 1,
            linkage: .letter("I")
        ),
        Rhyme(
            id: "old-king-cole",
            title: "Old King Cole",
            lines: [
                "Old King Cole was a merry old soul,",
                "And a merry old soul was he;",
                "He called for his pipe, and he called for his bowl,",
                "And he called for his fiddlers three."
            ],
            audioFileName: "old-king-cole.m4a",
            emoji: "👑",
            colorIndex: 3,
            linkage: .letter("K")
        ),
        Rhyme(
            id: "little-bo-peep",
            title: "Little Bo-Peep",
            lines: [
                "Little Bo-Peep has lost her sheep,",
                "And doesn't know where to find them.",
                "Leave them alone, and they'll come home,",
                "Wagging their tails behind them."
            ],
            audioFileName: "little-bo-peep.m4a",
            emoji: "🐑",
            colorIndex: 4,
            linkage: .letter("L")
        ),
        Rhyme(
            id: "queen-of-hearts",
            title: "The Queen of Hearts",
            lines: [
                "The Queen of Hearts, she made some tarts,",
                "All on a summer's day.",
                "The Knave of Hearts, he stole those tarts,",
                "And took them clean away."
            ],
            audioFileName: "queen-of-hearts.m4a",
            emoji: "👸",
            colorIndex: 6,
            linkage: .letter("Q")
        ),
        Rhyme(
            id: "ride-a-cock-horse",
            title: "Ride a Cock-Horse",
            lines: [
                "Ride a cock-horse to Banbury Cross,",
                "To see a fine lady upon a white horse.",
                "Rings on her fingers and bells on her toes,",
                "She shall have music wherever she goes."
            ],
            audioFileName: "ride-a-cock-horse.m4a",
            emoji: "🐴",
            colorIndex: 3,
            linkage: .letter("R")
        ),
        Rhyme(
            id: "tom-tom-the-pipers-son",
            title: "Tom, Tom, the Piper's Son",
            lines: [
                "Tom, Tom, the piper's son,",
                "Stole a pig, and away did run."
            ],
            audioFileName: "tom-tom-the-pipers-son.m4a",
            emoji: "🐷",
            colorIndex: 5,
            linkage: .letter("T")
        ),
        Rhyme(
            id: "wee-willie-winkie",
            title: "Wee Willie Winkie",
            lines: [
                "Wee Willie Winkie runs through the town,",
                "Upstairs and downstairs, in his nightgown,",
                "Rapping at the window, crying through the lock,",
                "\"Are the children all in bed? For now it's eight o'clock.\""
            ],
            audioFileName: "wee-willie-winkie.m4a",
            emoji: "🌙",
            colorIndex: 2,
            linkage: .letter("W")
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
