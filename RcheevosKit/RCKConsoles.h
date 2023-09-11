//
//  RCKConsoles.h
//  RcheevosKit
//
//  Created by C.W. Betts on 8/29/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//Must match defines in rc_consoles.h!
typedef NS_ENUM(int, RCKConsoleIdentifier) {
	RCKConsoleUnknown = 0,
	RCKConsoleMegaDrive = 1,
	RCKConsoleNintendo64 = 2,
	RCKConsoleSuperNintendo = 3,
	RCKConsoleGameBoy = 4,
	RCKConsoleGameBoyAdvance = 5,
	RCKConsoleGameBoyColor = 6,
	RCKConsoleNintendo = 7,
	RCKConsolePCEngine = 8,
	RCKConsoleSegaCD = 9,
	RCKConsoleSega32X = 10,
	RCKConsoleMasterSystem = 11,
	RCKConsolePlayStation = 12,
	RCKConsoleAtariLynx = 13,
	RCKConsoleNeoGeoPocket = 14,
	RCKConsoleGameGear = 15,
	RCKConsoleGamecube = 16,
	RCKConsoleAtariJaguar = 17,
	RCKConsoleNintendoDS = 18,
	RCKConsoleWii = 19,
	RCKConsoleWiiU = 20,
	RCKConsolePlayStation2 = 21,
	RCKConsoleXBox = 22,
	RCKConsoleMagnavoxOdyssey2 = 23,
	RCKConsolePokemonMini = 24,
	RCKConsoleAtari2600 = 25,
	RCKConsoleMSDOS = 26,
	RCKConsoleArcade = 27,
	RCKConsoleVirtualBoy = 28,
	RCKConsoleMSX = 29,
	RCKConsoleCommodore64 = 30,
	RCKConsoleZX81 = 31,
	RCKConsoleOric = 32,
	RCKConsoleSG1000 = 33,
	RCKConsoleVIC20 = 34,
	RCKConsoleAmiga = 35,
	RCKConsoleAtariST = 36,
	RCKConsoleAmstradPC = 37,
	RCKConsoleApple2 = 38,
	RCKConsoleSaturn = 39,
	RCKConsoleDreamcast = 40,
	RCKConsolePSP = 41,
	RCKConsoleCDI = 42,
	RCKConsole3DO NS_SWIFT_NAME(threeDO) = 43,
	RCKConsoleColecovision = 44,
	RCKConsoleIntellivision = 45,
	RCKConsoleVectrex = 46,
	RCKConsolePC8800 = 47,
	RCKConsolePC9800 = 48,
	RCKConsolePCFX = 49,
	RCKConsoleAtari5200 = 50,
	RCKConsoleAtari7800 = 51,
	RCKConsoleX68k = 52,
	RCKConsoleWonderswan = 53,
	RCKConsoleCassetteVision = 54,
	RCKConsoleSuperCassetteVision = 55,
	RCKConsoleNeoGeoCD = 56,
	RCKConsoleFairchildChannelF = 57,
	RCKConsoleFMTowns = 58,
	RCKConsoleZXSpectrum = 59,
	RCKConsoleGameAndWatch = 60,
	RCKConsoleNokiaNGage = 61,
	RCKConsoleNintendo3DS = 62,
	RCKConsoleSupervision = 63,
	RCKConsoleSharpX1 = 64,
	RCKConsoleTIC80 = 65,
	RCKConsoleThomsonto8 = 66,
	RCKConsolePC6000 = 67,
	RCKConsolePico = 68,
	RCKConsoleMegaduck = 69,
	RCKConsoleZeebo = 70,
	RCKConsoleArduboy = 71,
	RCKConsoleWASM4 = 72,
	RCKConsoleArcadia2001 = 73,
	RCKConsoleIntertonVC4000 = 74,
	RCKConsoleElektorTVGamesComputer = 75,
	RCKConsolePCEngineCD = 76,
	RCKConsoleAtariJaguarCD = 77,
	RCKConsoleNintendoDSi = 78,
	RCKConsoleTI83 = 79,
	RCKConsoleUZEBOX = 80,

	RCKConsoleHubs = 100,
	RCKConsoleEvents = 101
};

typedef NS_ENUM(char, RCKMemoryType) {
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


FOUNDATION_EXPORT NSString *RCKConsoleGetName(RCKConsoleIdentifier ident) NS_SWIFT_NAME(getter:RCKConsoleIdentifier.name(self:));

@interface RCKMemoryRegion : NSObject

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable NSArray<RCKMemoryRegion*>*)regionsBasedOnConsole:(RCKConsoleIdentifier)ident;

/*! First address of block as queried by RetroAchievements. */
@property (readonly) unsigned startAddress;
/*! Last address of block as queried by RetroAchievements. */
@property (readonly) unsigned endAddress;
/*! Real address for first address of block. */
@property (readonly) unsigned realAddress;
/*! \c RCKMemoryType for block. */
@property (readonly) RCKMemoryType memoryType;
/*! Short description of block. */
@property (readonly, copy) NSString *memoryDescription;

@end

NS_ASSUME_NONNULL_END
