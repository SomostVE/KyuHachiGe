# KyuHachiGe

Portable tools to simplify NEC PC-98 game setup and emulation on Windows.

KyuHachiGe helps you create a clean local PC-98 setup with:

- an English patched PC-98 game library
- optional original/raw PC-98 games
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

## 3. Folder structure

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

## 4. Menu explanation

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

You also need the RetroArch core (which you get after a quick setup):

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

The original library uses a different structure from the patched library.
The script extracts the studio archive, deletes the outer ZIP after successful extraction, and keeps the internal game ZIPs.

---

### `[Q] Quit`

Closes the menu.

---

## 5. RetroArch notes

SOON

## 6. Playnite setup

You will be to have download either some original games or patched games (option [2] or [o] )

### 1. setup an emulator
 
- click on the controler top left
- go to "Library" then "configure emulators"
- "add" at the bottom
Name : Retroarch PC98
Installation Folder : where is installed your retroarch (here is \KyuHachiGe\emulator\RetroArch-Win64)
Emulation specification : Retroarch
at the bottom there is "add" and will open a like, choose "Neko Project II Kai"
- "save" bottom right

### 2. Setup the scan

- Again click on the controler top left
- "Add game" -> "Emulated game" -> "Add scanner" (bottom left)
Scan with emulator : Retroarch PC98 | Profile : Neko Project II Kai
Scan Folder : it will be either \KyuHachiGe\PC98 Patched or \KyuHachiGe\PC98
X (check box) "save as auto-scan" which you can name PC98 Patched or PC98 library

"Start Scan" (bottom right)
and now it will scan the folder, show a new windows with the list of everything and just click import


## 7. Important note

KyuHachiGe is only a helper for organizing and preparing a local PC-98 setup. I made this because for such a old system there is actually almost nothing to help enjoying it

you can also check this website (which i'm not related to but it helped me) : https://gang-fight.com/projects/98faq/
