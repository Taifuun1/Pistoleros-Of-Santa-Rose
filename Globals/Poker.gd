extends Node

enum SUITS {
	HEARTS,
	DIAMONDS,
	SPADES,
	CLUBS
}

const CARDS = [
	{
		"name": "Two of Hearts",
		"amount": 2,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Three of Hearts",
		"amount": 3,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Four of Hearts",
		"amount": 4,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Five of Hearts",
		"amount": 5,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Six of Hearts",
		"amount": 6,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Seven of Hearts",
		"amount": 7,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Eight of Hearts",
		"amount": 8,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Nine of Hearts",
		"amount": 9,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Ten of Hearts",
		"amount": 10,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Jack of Hearts",
		"amount": 11,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Queen of Hearts",
		"amount": 12,
		"suit": SUITS.HEARTS
	},
	{
		"name": "King of Hearts",
		"amount": 13,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Ace of Hearts",
		"amount": 14,
		"suit": SUITS.HEARTS
	},
	{
		"name": "Two of Diamonds",
		"amount": 2,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Three of Diamonds",
		"amount": 3,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Four of Diamonds",
		"amount": 4,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Five of Diamonds",
		"amount": 5,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Six of Diamonds",
		"amount": 6,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Seven of Diamonds",
		"amount": 7,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Eight of Diamonds",
		"amount": 8,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Nine of Diamonds",
		"amount": 9,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Ten of Diamonds",
		"amount": 10,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Jack of Diamonds",
		"amount": 11,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Queen of Diamonds",
		"amount": 12,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "King of Diamonds",
		"amount": 13,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Ace of Diamonds",
		"amount": 14,
		"suit": SUITS.DIAMONDS
	},
	{
		"name": "Two of Spades",
		"amount": 2,
		"suit": SUITS.SPADES
	},
	{
		"name": "Three of Spades",
		"amount": 3,
		"suit": SUITS.SPADES
	},
	{
		"name": "Four of Spades",
		"amount": 4,
		"suit": SUITS.SPADES
	},
	{
		"name": "Five of Spades",
		"amount": 5,
		"suit": SUITS.SPADES
	},
	{
		"name": "Six of Spades",
		"amount": 6,
		"suit": SUITS.SPADES
	},
	{
		"name": "Seven of Spades",
		"amount": 7,
		"suit": SUITS.SPADES
	},
	{
		"name": "Eight of Spades",
		"amount": 8,
		"suit": SUITS.SPADES
	},
	{
		"name": "Nine of Spades",
		"amount": 9,
		"suit": SUITS.SPADES
	},
	{
		"name": "Ten of Spades",
		"amount": 10,
		"suit": SUITS.SPADES
	},
	{
		"name": "Jack of Spades",
		"amount": 11,
		"suit": SUITS.SPADES
	},
	{
		"name": "Queen of Spades",
		"amount": 12,
		"suit": SUITS.SPADES
	},
	{
		"name": "King of Spades",
		"amount": 13,
		"suit": SUITS.SPADES
	},
	{
		"name": "Ace of Spades",
		"amount": 14,
		"suit": SUITS.SPADES
	},
	{
		"name": "Two of Clubs",
		"amount": 2,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Three of Clubs",
		"amount": 3,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Four of Clubs",
		"amount": 4,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Five of Clubs",
		"amount": 5,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Six of Clubs",
		"amount": 6,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Seven of Clubs",
		"amount": 7,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Eight of Clubs",
		"amount": 8,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Nine of Clubs",
		"amount": 9,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Ten of Clubs",
		"amount": 10,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Jack of Clubs",
		"amount": 11,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Queen of Clubs",
		"amount": 12,
		"suit": SUITS.CLUBS
	},
	{
		"name": "King of Clubs",
		"amount": 13,
		"suit": SUITS.CLUBS
	},
	{
		"name": "Ace of Clubs",
		"amount": 14,
		"suit": SUITS.CLUBS
	}
]

const HANDS = [
	"Royal Straight Flush",
	"Straight Flush",
	"Four of a kind",
	"Full house",
	"Flush",
	"Straight",
	"Three of a kind",
	"Two pairs",
	"Two of a kind",
	"High card"
]

var scripted = false
var scriptName = null
