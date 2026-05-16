# KyuHachiGe

Portable tools to simplify NEC PC-98 game setup and emulation on Windows.

KyuHachiGe helps you create a clean local PC-98 setup with:

- an English patched PC-98 game library
- optional original PC-98 games
- RetroArch portable for emulation
- Playnite as a frontend to list and launch your games

---

## 1. First setup

Create a folder anywhere on your computer.

The folder name does not matter. Example:

```text
D:\Games\KyuHachiGe
```

Inside that folder (here "KyuHachiGe" in this example), create a folder named:

```text
script
```

Download `KyuHachiGe.bat` and move it inside the `script` folder.

Now double-click:

```text
KyuHachiGe.bat
```

At first launch, the `.bat` will automatically create the required folders and download the PowerShell scripts from GitHub.

After that, you will see this menu:

```text
[1] Check environment
[2] Download patched library
[3] Check patched games library update
[4] Download Playnite (to list your games)
[5] Download RetroArch portable 64bit (for emulation)

[O] Download original games
[Q] Quit
```

---

## 2. Recommended install order

For a normal setup, use this order:

```text
[1] Check environment
[2] Download patched library
[5] Download RetroArch portable 64bit (for emulation)
[4] Download Playnite (to list your games)
```

The original games download is optional:

```text
[O] Download original games
```

Use it only if you also want the original PC-98 library (it's 80Go).

---

## 3.1. Folder structure

After setup, your folder will look like this if you want both patched and original games :

```text
KyuHachiGe
├─ emulator
├─ frontend
├─ PC98
├─ PC98 Patched
└─ script
   ├─ KyuHachiGe.bat
   └─ powershell
      ├─ 00_check_environment.ps1
      ├─ 01_download_patched_library.ps1
      ├─ 02_check_patched_games_update.ps1
      └─ 90_download_original_games.ps1
```

### Folder roles

| Folder | Purpose |
|---|---|
| `emulator` | RetroArch portable goes here. Official website: https://www.retroarch.com/?page=platforms |
| `frontend` | Playnite portable goes here. Official website: https://playnite.link |
| `PC98 Patched` | English patched games are downloaded from: https://archive.org/details/nec-pc-9801-translations |
| `PC98` | Optional original PC-98 library is downloaded from: https://archive.org/details/NeoKobe-NecPc-98012017-11-17 |
| `script` | Contains `KyuHachiGe.bat` and the downloaded PowerShell scripts. |

---

## 3.2. Menu explanation (if you want some informations)

### `[1] Check environment`

Checks that the basic KyuHachiGe folders exist.

It creates or verifies:

```text
emulator
frontend
script\powershell
```

It also checks if RetroArch and the PC-98 core are present.

### `[2] Download patched library`

Downloads the English patched PC-98 games.

Output folder:

```text
PC98 Patched
```

The games stay zipped because Playnite can scan and launch zipped games.

---

### `[3] Check patched games library update`

Checks the patched library against the online source.

It detects:

- missing ZIP files
- changed ZIP files
- already up-to-date files

If something is missing or outdated, the script can download it again.

---

### `[4] Download Playnite (to list your games)`

Opens the official Playnite website.

Playnite is used as the game library frontend. It lets you display your PC-98 games with covers, metadata, and a Play button.

Recommended location:

```text
frontend
```

---

### `[5] Download RetroArch portable 64bit (for emulation)`

Opens the official RetroArch download page.

Download the Windows 64-bit portable version and extract it into:

```text
emulator
```

Recommended result:

```text
emulator
└─ RetroArch-Win64
   └─ retroarch.exe
```

You also need the RetroArch core (which you get after with the retroarch setup):

```text
NEC - PC-98 (Neko Project II Kai)
```

Core file:

```text
np2kai_libretro.dll
```

Expected location:

```text
emulator\RetroArch-Win64\cores\np2kai_libretro.dll
```

---

### `[O] Download original games`

Downloads the original PC-98 collection.

This is optional.

Warning:

```text
It is large (80 GB).
```

Output folder:

```text
PC98
```

it will download, unzip and keep a folder for each studio with the games and zipped files inside.

---

### `[Q] Quit`

Closes the menu.

---

## 4. RetroArch notes

start "retroarch.exe"

PC98 core installation :

- Main menu -> Load Core -> Download a core
- scroll to the N, you will find "NEC - PC-98 (Neko Project II Kai)"

and thats about it
in most cases, BIOS files are not required but if you do need :  https://ia800401.us.archive.org/view_archive.php?archive=/18/items/NeoKobe-NecPc-98012017-11-17/BIOS.zip

but you will want a new font and better sounds, you can use same as me in "emulator_system", dump everything in "emulator\RetroArch-Win64\system\np2kai\" next to "np2kai.cfg" which should already be here

if np2kai.cfg isnt here try to launch the core :
- Main Menu -> Load Core -> NEC - PC-98 (Neko Project II Kai)
- let it load until it become a black screen with nothing (it's about 10 seconds max)
- check your folder again
---

## 5. Playnite setup

You will need to download either some original games or patched games (option [2] or [o] )

### a. setup an emulator
 
- click on the controller top left
- go to "Library" then "configure emulators"
- "add" at the bottom
Name : Retroarch PC98
Installation Folder : where is installed your retroarch (here is \KyuHachiGe\emulator\RetroArch-Win64)
Emulation specification : Retroarch
at the bottom there is "add" and will open a like, choose "Neko Project II Kai"
- "save" bottom right

### b. Setup the scan

- Again click on the controller top left
- "Add game" -> "Emulated game" -> "Add scanner" (bottom left)
Scan with emulator : Retroarch PC98 | Profile : Neko Project II Kai
Scan Folder : it will be either \KyuHachiGe\PC98 Patched or \KyuHachiGe\PC98
X (check box) "save as auto-scan" which you can name PC98 Patched or PC98 library

"Start Scan" (bottom right)
and now it will scan the folder, show a new windows with the list of everything and just click import

Playnite will re-scan everytime you open the app with this configuration

### c. Additionnal step
you might want the images and stuff ? 

- Controller -> Add-on -> under the browser section click on "metadata sources"
- look for playniteVndb (check later if you want others) -> install
- Controller -> library -> Download Metadata -> "Next" bottom right (dont no need to change anything)
- at the top next to "apply to all" click and select "VNDB" then apply to all

if you "edit" a game you will see bottom right "download metadat" where you can search for the name of the game, i mainly use that if the first one doesnt work well

## 6. Important note

KyuHachiGe is only a helper for organizing and preparing a local PC-98 setup. I made this because for such a old system there is actually almost nothing to help enjoying it

you can also check this website (which i'm not related to but it helped me) : https://gang-fight.com/projects/98faq/
