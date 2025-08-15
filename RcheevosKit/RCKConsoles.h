//
//  RCKConsoles.h
//  RcheevosKit
//
//  Created by C.W. Betts on 8/29/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//Must match defines in rc_consoles.h!
typedef NS_ENUM(uint32_t, RCKConsoleIdentifier) {
	/// Unknown or default console
	RCKConsoleUnknown = 0,
	/// Sega MegaDrive
	RCKConsoleMegaDrive = 1,
	/// Nintendo 64
	RCKConsoleNintendo64 = 2,
	/// Super Nintendo Entertainment System
	RCKConsoleSuperNintendo = 3,
	/// Game Boy
	RCKConsoleGameBoy = 4,
	/// Game Boy Advance
	RCKConsoleGameBoyAdvance = 5,
	/// Game Boy Color
	RCKConsoleGameBoyColor = 6,
	/// Nintendo Entertainment System
	RCKConsoleNintendo = 7,
	/// PC Engine
	RCKConsolePCEngine = 8,
	/// Sega CD
	RCKConsoleSegaCD = 9,
	/// Sega 32x
	RCKConsoleSega32X = 10,
	/// Sega Master System
	RCKConsoleMasterSystem = 11,
	/// Sony PlayStation
	RCKConsolePlayStation = 12,
	/// Atari Lynx
	RCKConsoleAtariLynx = 13,
	/// NeoGeo Pocket
	RCKConsoleNeoGeoPocket = 14,
	/// Sega Game Gear
	RCKConsoleGameGear = 15,
	/// Nintendo Gamecube
	RCKConsoleGamecube = 16,
	/// Atari Jaguar
	RCKConsoleAtariJaguar = 17,
	/// Nintendo DS
	RCKConsoleNintendoDS = 18,
	/// Nintendo Wii
	RCKConsoleWii = 19,
	/// Nintendo Wii U
	RCKConsoleWiiU = 20,
	/// Sony PlayStation 2
	RCKConsolePlayStation2 = 21,
	/// Microsoft Xbox
	RCKConsoleXBox = 22,
	/// Magnavox Odyssey 2
	RCKConsoleMagnavoxOdyssey2 = 23,
	/// Pokémon Mini
	RCKConsolePokemonMini = 24,
	/// Atari 2600
	RCKConsoleAtari2600 = 25,
	/// MS-DOS
	RCKConsoleMSDOS = 26,
	/// Arcade
	RCKConsoleArcade = 27,
	/// Nintendo VirtualBoy
	RCKConsoleVirtualBoy = 28,
	/// MSX
	RCKConsoleMSX = 29,
	/// Commodore 64
	RCKConsoleCommodore64 = 30,
	/// ZX81
	RCKConsoleZX81 = 31,
	/// Oric
	RCKConsoleOric = 32,
	// SG1000
	RCKConsoleSG1000 = 33,
	/// Commodore VIC 20
	RCKConsoleVIC20 = 34,
	/// Commodore Amiga
	RCKConsoleAmiga = 35,
	/// Atari ST
	RCKConsoleAtariST = 36,
	/// Amstrad PC
	RCKConsoleAmstradPC = 37,
	/// Apple II
	RCKConsoleApple2 = 38,
	/// Sega Saturn
	RCKConsoleSaturn = 39,
	/// Sega Dreamcast
	RCKConsoleDreamcast = 40,
	/// Sony PlayStation Pocket
	RCKConsolePSP = 41,
	/// Phillips CD-I
	RCKConsoleCDI = 42,
	/// 3DO
	RCKConsole3DO NS_SWIFT_NAME(threeDO) = 43,
	/// Colecovision
	RCKConsoleColecovision = 44,
	/// Intellivision
	RCKConsoleIntellivision = 45,
	/// Vectrex
	RCKConsoleVectrex = 46,
	/// NEC PC-8000/8800
	RCKConsolePC8800 = 47,
	/// NEC PC-9800
	RCKConsolePC9800 = 48,
	/// NEC PC-FX
	RCKConsolePCFX = 49,
	/// Atari 5200
	RCKConsoleAtari5200 = 50,
	/// Atari 7200
	RCKConsoleAtari7800 = 51,
	/// x68k
	RCKConsoleX68k = 52,
	/// Wonderswan
	RCKConsoleWonderswan = 53,
	/// Cassette Vision
	RCKConsoleCassetteVision = 54,
	/// Super Cassette Vision
	RCKConsoleSuperCassetteVision = 55,
	/// Neo Geo CD
	RCKConsoleNeoGeoCD = 56,
	/// Fairchild Channel F
	RCKConsoleFairchildChannelF = 57,
	/// FM Towns
	RCKConsoleFMTowns = 58,
	/// ZX Spectrum
	RCKConsoleZXSpectrum = 59,
	/// Game & Watch
	RCKConsoleGameAndWatch = 60,
	/// Nokia N-Gage
	RCKConsoleNokiaNGage = 61,
	/// Nintendo 3DS
	RCKConsoleNintendo3DS = 62,
	/// Watara Supervision
	RCKConsoleSupervision = 63,
	/// Sharp X1
	RCKConsoleSharpX1 = 64,
	/// TIC 80
	RCKConsoleTIC80 = 65,
	/// Thomson TO8
	RCKConsoleThomsonTO8 = 66,
	/// PC-6000
	RCKConsolePC6000 = 67,
	/// Sega Pico
	RCKConsolePico = 68,
	/// Megaduck
	RCKConsoleMegaduck = 69,
	/// Zeebo
	RCKConsoleZeebo = 70,
	/// Arduboy
	RCKConsoleArduboy = 71,
	/// Wasm4
	RCKConsoleWASM4 = 72,
	/// Arcadia 2001
	RCKConsoleArcadia2001 = 73,
	/// Interton VC4000
	RCKConsoleIntertonVC4000 = 74,
	/// Elektor TV Games Computer
	RCKConsoleElektorTVGamesComputer = 75,
	/// PC Engine, CDs
	RCKConsolePCEngineCD = 76,
	/// Atari Jaguar, CDs
	RCKConsoleAtariJaguarCD = 77,
	/// Nintendo DSi
	RCKConsoleNintendoDSi = 78,
	/// Texas Instruments TI-83 graphing calculator
	RCKConsoleTI83 = 79,
	/// UZEBOX
	RCKConsoleUZEBOX = 80,
	/// Famicom Disk System
	RCKConsoleFamicomDiskSystem = 81,

	// Hubs
	RCKConsoleHubs = 100,
	// Events
	RCKConsoleEvents = 101,
	// Standalones
	RCKConsoleStandalone = 102
};

FOUNDATION_EXPORT NSString *RCKConsoleGetName(RCKConsoleIdentifier ident) NS_SWIFT_NAME(getter:RCKConsoleIdentifier.description(self:));

typedef NS_ENUM(unsigned char, RCKMemoryType) {
	/*! normal system memory */
	RCKMemoryTypeSystemRAM,
	/*! memory that persists between sessions */
	RCKMemoryTypeSaveRAM,
	/*! memory reserved for graphical processing */
	RCKMemoryTypeVideoRAM,
	/*! memory that maps to read only data */
	RCKMemoryTypeReadOnly,
	/*! memory for interacting with system components */
	RCKMemoryTypeHardwareController,
	/*! secondary address space that maps to real memory in system RAM */
	RCKMemoryTypeVirtualRAM,
	/*! these addresses don't really exist */
	RCKMemoryTypeUnused
};

@interface RCKMemoryRegion : NSObject

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable NSArray<RCKMemoryRegion*>*)regionsBasedOnConsole:(RCKConsoleIdentifier)ident;

/*! First address of block as queried by RetroAchievements. */
@property (readonly) unsigned startAddress;
/*! Last address of block as queried by RetroAchievements. */
@property (readonly) unsigned endAddress;
/*! Real address for first address of block. */
@property (readonly) unsigned realAddress;
/*! `RCKMemoryType` for block. */
@property (readonly) RCKMemoryType memoryType;
/*! Short description of block. */
@property (readonly, copy) NSString *memoryDescription;

@end

NS_ASSUME_NONNULL_END
