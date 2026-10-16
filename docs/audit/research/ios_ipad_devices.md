# iOS / iPadOS device spec research (accessed 2026-10-15)

Conventions
- **[A]** = Apple primary source (support.apple.com tech specs, apple.com newsroom, Apple Metal docs).
- **[S]** = secondary source (identifier mapping, RAM, some release dates). Apple does not publish the `iPhoneNN,N` mapping or iPhone RAM.
- **[X]** = read from the CoreSimulator device-type profiles installed with Xcode 27.0 on this machine (`/Library/Developer/CoreSimulator/Profiles/DeviceTypes/*.simdevicetype/Contents/Resources/profile.plist`, keys `modelIdentifier` / `representedModelIdentifiers`). These are Apple-shipped files, but they are not public documentation.
- Display ppi, resolution, size, refresh, SoC, CPU/GPU/NE cores and camera values all come from the Apple tech-specs page linked in each row. Apple lists **460 ppi for every 6.1/6.3/6.5/6.7/6.9-inch iPhone OLED from iPhone 14 Pro onward, including 14 (6.1)**. Only the 6.7-inch 12 Pro Max, 13 Pro Max and 14 Plus are 458 ppi.
- "60 Hz" for non-ProMotion devices: Apple does not state a Hz value for them. It lists "ProMotion … up to 120Hz" only on ProMotion models, so 60 Hz is the standard figure but Apple does not state it.

## 1. iPhone table (iPhone13,x → newest, Oct 2026)

Identifier mapping is [S] (everymac + adamawolf gist), and it is corroborated by [X] Xcode 27 simulator profiles for every row. Release date = first retail availability.

| Identifier | Marketing name | Released | SoC | CPU (P+E) | GPU | NE | RAM (unofficial [S]) | Display | Resolution | ppi | Max refresh | Rear cameras | Front | Apple spec URL |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| iPhone13,1 | iPhone 12 mini | 2020-11-13 [S] | A14 Bionic | 2+4 | 4 | 16 | 4 GB | 5.4" OLED | 2340×1080 | 476 | 60 Hz | 12MP Wide f/1.6; 12MP UW f/2.4 | 12MP f/2.2 | support.apple.com/en-us/111877 |
| iPhone13,2 | iPhone 12 | 2020-10-23 [S] | A14 Bionic | 2+4 | 4 | 16 | 4 GB | 6.1" | 2532×1170 | 460 | 60 Hz | 12MP Wide f/1.6; 12MP UW f/2.4 | 12MP f/2.2 | /111876 |
| iPhone13,3 | iPhone 12 Pro | 2020-10-23 [S] | A14 Bionic | 2+4* | 4* | 16* | 6 GB | 6.1" | 2532×1170 | 460 | 60 Hz | 12MP Wide f/1.6; 12MP UW f/2.4; 12MP 2x Tele f/2.0; LiDAR | 12MP f/2.2 | /111875 |
| iPhone13,4 | iPhone 12 Pro Max | 2020-11-13 [S] | A14 Bionic | 2+4* | 4* | 16* | 6 GB | 6.7" | 2778×1284 | 458 | 60 Hz | 12MP Wide f/1.6; 12MP UW f/2.4; 12MP 2.5x Tele f/2.2; LiDAR | 12MP f/2.2 | /111874 |
| iPhone14,4 | iPhone 13 mini | 2021-09-24 [S] | A15 Bionic | 2+4 | 4 | 16 | 4 GB | 5.4" | 2340×1080 | 476 | 60 Hz | 12MP Main f/1.6; 12MP UW f/2.4 | 12MP f/2.2 | /111873 |
| iPhone14,5 | iPhone 13 | 2021-09-24 [S] | A15 Bionic | 2+4 | 4 | 16 | 4 GB | 6.1" | 2532×1170 | 460 | 60 Hz | 12MP Main f/1.6; 12MP UW f/2.4 | 12MP f/2.2 | /111872 |
| iPhone14,2 | iPhone 13 Pro | 2021-09-24 [S] | A15 Bionic | 2+4 | **5** | 16 | 6 GB | 6.1" | 2532×1170 | 460 | 120 Hz ProMotion | 12MP Wide f/1.5; 12MP UW f/1.8; 12MP 3x Tele f/2.8; LiDAR | 12MP f/2.2 | /111871 |
| iPhone14,3 | iPhone 13 Pro Max | 2021-09-24 [S] | A15 Bionic | 2+4 | **5** | 16 | 6 GB | 6.7" | 2778×1284 | 458 | 120 Hz ProMotion | same as 13 Pro | 12MP f/2.2 | /111870 |
| iPhone14,6 | iPhone SE (3rd gen) | 2022-03-18 [S] | A15 Bionic | 2+4 | 4 | 16 | 4 GB | 4.7" LCD | 1334×750 | 326 | 60 Hz | 12MP f/1.8 | 7MP f/2.2 | /111866 |
| iPhone14,7 | iPhone 14 | 2022-09-16 [S] | A15 Bionic | 2+4 | 5 | 16 | 6 GB | 6.1" | 2532×1170 | 460 | 60 Hz | 12MP Main f/1.5; 12MP UW f/2.4 | 12MP f/1.9 | /111850 |
| iPhone14,8 | iPhone 14 Plus | 2022-10-07 [S] | A15 Bionic | 2+4 | 5 | 16 | 6 GB | 6.7" | 2778×1284 | 458 | 60 Hz | 12MP Main f/1.5; 12MP UW f/2.4 | 12MP f/1.9 | /111854 |
| iPhone15,2 | iPhone 14 Pro | 2022-09-16 [S] | A16 Bionic | 2+4 | 5 | 16 | 6 GB | 6.1" | 2556×1179 | 460 | 120 Hz ProMotion | 48MP Main f/1.78; 12MP UW f/2.2; 12MP 3x Tele f/2.8; LiDAR | 12MP f/1.9 | /111849 |
| iPhone15,3 | iPhone 14 Pro Max | 2022-09-16 [S] | A16 Bionic | 2+4 | 5 | 16 | 6 GB | 6.7" | 2796×1290 | 460 | 120 Hz ProMotion | same as 14 Pro | 12MP f/1.9 | /111846 |
| iPhone15,4 | iPhone 15 | 2023-09-22 [S] | A16 Bionic | 2+4 | 5 | 16 | 6 GB | 6.1" | 2556×1179 | 460 | 60 Hz | 48MP Main f/1.6; 12MP UW f/2.4 | 12MP f/1.9 | /111831 |
| iPhone15,5 | iPhone 15 Plus | 2023-09-22 [S] | A16 Bionic | 2+4 | 5 | 16 | 6 GB | 6.7" | 2796×1290 | **460** | 60 Hz | 48MP Main f/1.6; 12MP UW f/2.4 | 12MP f/1.9 | /111830 |
| iPhone16,1 | iPhone 15 Pro | 2023-09-22 [S] | A17 Pro | 2+4 | 6 | 16 | 8 GB | 6.1" | 2556×1179 | 460 | 120 Hz ProMotion | 48MP Main f/1.78; 12MP UW f/2.2; 12MP 3x Tele f/2.8; LiDAR | 12MP f/1.9 | /111829 |
| iPhone16,2 | iPhone 15 Pro Max | 2023-09-22 [S] | A17 Pro | 2+4 | 6 | 16 | 8 GB | 6.7" | 2796×1290 | 460 | 120 Hz ProMotion | 48MP Main f/1.78; 12MP UW f/2.2; 12MP 5x Tele f/2.8; LiDAR | 12MP f/1.9 | /111828 |
| iPhone17,3 | iPhone 16 | 2024-09-20 [S] | **A18** | 2+4 | **5** | 16 | 8 GB | 6.1" | 2556×1179 | **460** | 60 Hz | 48MP Fusion f/1.6; 12MP UW **f/2.2** | 12MP f/1.9 | /121029 |
| iPhone17,4 | iPhone 16 Plus | 2024-09-20 [S] | A18 | 2+4 | 5 | 16 | 8 GB | 6.7" | 2796×1290 | **460** | 60 Hz | 48MP Fusion f/1.6; 12MP UW f/2.2 | 12MP f/1.9 | /121030 |
| iPhone17,1 | iPhone 16 Pro | 2024-09-20 [S] | A18 Pro | 2+4 | 6 | **16** | 8 GB | **6.3"** | 2622×1206 | 460 | 120 Hz ProMotion | 48MP Fusion f/1.78; **48MP UW f/2.2**; **12MP 5x Tele f/2.8**; LiDAR | 12MP f/1.9 | /121031 |
| iPhone17,2 | iPhone 16 Pro Max | 2024-09-20 [S] | A18 Pro | 2+4 | 6 | 16 | 8 GB | **6.9"** | 2868×1320 | 460 | 120 Hz ProMotion | same as 16 Pro (5x tele) | 12MP f/1.9 | /121032 |
| iPhone17,5 | iPhone 16e | 2025-02-28 [S] | A18 | 2+4 | **4** | 16 | 8 GB | 6.1" | 2532×1170 | 460 | 60 Hz | 48MP Fusion f/1.6 (single) | 12MP f/1.9 | /122208 |
| iPhone18,3 | iPhone 17 | 2025-09-19 [A] | A19 | 2+4 | 5 (w/ Neural Accelerators) | 16 | 8 GB | 6.3" | 2622×1206 | 460 | 120 Hz ProMotion | 48MP Fusion Main f/1.6; 48MP Fusion UW f/2.2 | 18MP Center Stage f/1.9 | /125089 |
| iPhone18,4 | iPhone Air | 2025-09-19 [A] | A19 Pro | 2+4 | 5 (w/ NA) | 16 | 12 GB | 6.5" | 2736×1260 | 460 | 120 Hz ProMotion | 48MP Fusion Main f/1.6 (single) | 18MP Center Stage f/1.9 | /125092 |
| iPhone18,1 | iPhone 17 Pro | 2025-09-19 [A] | A19 Pro | 2+4 | 6 (w/ NA) | 16 | 12 GB | 6.3" | 2622×1206 | 460 | 120 Hz ProMotion | 48MP Main f/1.78; 48MP UW f/2.2; 48MP 4x Tele (100 mm) f/2.8; LiDAR | 18MP Center Stage f/1.9 | /125090 |
| iPhone18,2 | iPhone 17 Pro Max | 2025-09-19 [A] | A19 Pro | 2+4 | 6 (w/ NA) | 16 | 12 GB | 6.9" | 2868×1320 | 460 | 120 Hz ProMotion | same as 17 Pro | 18MP Center Stage f/1.9 | /125091 |
| iPhone18,5 | iPhone 17e | 2026-03-11 [A] | A19 | 2+4 | 4 (w/ NA) | 16 | 8 GB (inferred, unverified) | 6.1" | 2532×1170 | 460 | 60 Hz | 48MP Fusion Main f/1.6 (single) | 12MP f/1.9 | /126470 |
| iPhone19,2 | iPhone 18 Pro | 2026-09-18 [A] | A20 Pro (2 nm) | 2 "super" + 4 E | 7 (w/ NA) | Dual 16-core (32) | not published; 12 GB rumored (Kuo), unverified | 6.3" | 2622×1206 | 460 | 120 Hz ProMotion | 48MP Main, variable aperture f/1.48/1.8/2.8/4.0; 48MP UW f/2.2; 48MP 4x Tele (100 mm) f/2.8; LiDAR | 18MP Center Stage f/1.9 | /148590 |
| iPhone19,3 (US) / iPhone19,7 (intl) | iPhone 18 Pro Max | 2026-09-18 [A] | A20 Pro | 2 super + 4 E | 7 | Dual 16-core | as above | 6.9" | 2868×1320 | 460 | 120 Hz ProMotion | same as 18 Pro | 18MP f/1.9 | /148591 |

\* The iPhone 12 Pro and 12 Pro Max Apple pages list only "A14 Bionic chip / Next-generation Neural Engine", with no core counts. The core counts given are those Apple lists for the same A14 chip on the iPhone 12 page (/111876).

Other notes
- **iPhone 13 Pro, 13 Pro Max, 14 and 14 Plus have a 5-core GPU.** The 13 and 13 mini have 4 cores, even though all of these use the A15. The 16e has 4 GPU cores and the 16 and 16 Plus have 5, all on the A18. The 17e has 4 and the 17 has 5, both on the A19. The Air (A19 Pro) has 5 and the 17 Pro has 6.
- Apple calls the 2024+ chips **"A18", "A18 Pro", "A19", "A19 Pro", "A20 Pro"**. The word "Bionic" was dropped after the A16 Bionic, and the A17 Pro never used it.
- From the 18 Pro onward, Apple describes the CPU as "2 super cores and 4 efficiency cores" (18 Pro pages). The M5 iPad Pro uses the same "super cores" wording.
- In 2026 there is **no non-Pro iPhone 18 or iPhone 18e** (Apple ID page 108044 lists only 18 Pro, 18 Pro Max and 17e for 2026). The gist comments and everymac mention an "iPhone Duo" (iPhone19,4 or 19,6). It is pending/unreleased and unverified, so it is excluded here.
- The RAM column is entirely [S]: iphonescompare.com for 12 through 17 Pro Max, cross-checked with 9to5mac. Apple publishes none of it. The Air figure of 12 GB has a conflicting secondary listing of 8 GB in one search-snippet source. Treat it as 12 GB with medium confidence. The 17e and 18 Pro figures are **unverified**.
- Release dates marked [S] come from Wikipedia "List of iPhone models". The 17-family, 17e and 18 Pro dates come from the Apple newsroom.

## 2. iPad table (iPadOS 16 → current)

iPadOS 16 compatible list (Apple [A], support.apple.com/en-us/103267): iPad Pro 12.9 (1st–6th gen), iPad Pro 11 (1st–4th), iPad Pro 10.5, iPad Pro 9.7, iPad 5th–10th gen, iPad mini 5th–6th, iPad Air 3rd–5th. The current lineup adds the later models below.

Identifiers are [S] from the gist and everymac. [X] marks an identifier confirmed by a simulator profile. Specs are [A] from the linked tech-specs page.

| Identifiers | Name | Year | SoC (CPU / GPU / NE) | Display | Resolution | ppi | Refresh | Apple spec URL |
|---|---|---|---|---|---|---|---|---|
| iPad12,1 / 12,2 [X 12,2] | iPad (9th gen) | 2021 | A13 Bionic (cores not listed) | 10.2" LCD | 2160×1620 | 264 | 60 Hz | /111898 |
| iPad13,4–13,7 [X 13,5] | iPad Pro 11" (3rd gen) | 2021 | M1 (4P+4E / 8 / 16) | 11" LCD | 2388×1668 | 264 | 120 Hz ProMotion | /111897 |
| iPad13,8–13,11 [X 13,10] | iPad Pro 12.9" (5th gen) | 2021 | M1 (4+4 / 8 / 16) | 12.9" mini-LED | 2732×2048 | 264 | 120 Hz ProMotion | /111896 |
| iPad14,1 / 14,2 [X 14,1] | iPad mini (6th gen) | 2021 | A15 Bionic (2+4 / 5 / 16) | 8.3" LCD | 2266×1488 | 326 | 60 Hz | /111886 |
| iPad13,16 / 13,17 [X 13,17] | iPad Air (5th gen) | 2022 | M1 (4+4 / 8 / 16) | 10.9" LCD | 2360×1640 | 264 | 60 Hz | /111887 |
| iPad13,18 / 13,19 [X 13,18] | iPad (10th gen) | 2022 | A14 Bionic (6-core / 4 / 16) | 10.9" LCD | 2360×1640 | 264 | 60 Hz | /111840 |
| iPad14,3 / 14,4 [X] | iPad Pro 11" (4th gen) | 2022 | M2 (4+4 / 10 / 16) | 11" LCD | 2388×1668 | 264 | 120 Hz ProMotion | /111842 |
| iPad14,5 / 14,6 [X 14,5] | iPad Pro 12.9" (6th gen) | 2022 | M2 (4+4 / 10 / 16) | 12.9" mini-LED | 2732×2048 | 264 | 120 Hz ProMotion | /111841 |
| iPad14,8 / 14,9 [X 14,9] | iPad Air 11" (M2) | 2024 | M2 (4+4 / 9 / 16) | 11" (10.86") LCD | 2360×1640 | 264 | 60 Hz | /119894 |
| iPad14,10 / 14,11 [X 14,11] | iPad Air 13" (M2) | 2024 | M2 (4+4 / 9 / 16) | 13" (12.9") LCD | 2732×2048 | 264 | 60 Hz | /119893 |
| iPad16,3 / 16,4 [X 16,4] | iPad Pro 11" (M4) | 2024 | M4 (3+6 or 4+6 by storage / 10 / 16) | 11" (11.1") tandem OLED | 2420×1668 | 264 | 10–120 Hz ProMotion | /119892 |
| iPad16,5 / 16,6 [X 16,6] | iPad Pro 13" (M4) | 2024 | M4 (3+6 or 4+6 / 10 / 16) | 13" tandem OLED | 2752×2064 | 264 | 10–120 Hz ProMotion | /119891 |
| iPad16,1 / 16,2 [X 16,2] | iPad mini (A17 Pro) | 2024 | A17 Pro (2+4 / 5 / 16) | 8.3" LCD | 2266×1488 | 326 | 60 Hz | /121456 |
| iPad15,7 / 15,8 [X 15,7] | iPad (A16) | 2025 | A16 (5-core / 4 / 16) | 11" (10.86") LCD | 2360×1640 | 264 | 60 Hz | /122240 |
| iPad15,3 / 15,4 [X 15,3] | iPad Air 11" (M3) | 2025 | M3 (4+4 / 9 / 16) | 11" LCD | 2360×1640 | 264 | 60 Hz | /122241 |
| iPad15,5 / 15,6 [X 15,5] | iPad Air 13" (M3) | 2025 | M3 (4+4 / 9 / 16) | 13" LCD | 2732×2048 | 264 | 60 Hz | /122242 |
| iPad17,1 / 17,2 [X 17,2] | iPad Pro 11" (M5) | 2025 | M5 (3 super+6E or 4+6 / 10 / 16) | 11" tandem OLED | 2420×1668 | 264 | 10–120 Hz ProMotion | /125406 |
| iPad17,3 / 17,4 [X 17,4] | iPad Pro 13" (M5) | 2025 | M5 (3+6 or 4+6 / 10 / 16) | 13" tandem OLED | 2752×2064 | 264 | 10–120 Hz ProMotion | /125407 |
| iPad16,8 / 16,9 [X 16,9] | iPad Air 11" (M4) | 2026 (avail. 2026-03-11) | M4 (3+5 / 9 / 16) | 11" LCD | 2360×1640 | 264 | 60 Hz | /126471 |
| iPad16,10 / 16,11 [X 16,11] | iPad Air 13" (M4) | 2026 | M4 (3+5 / 9 / 16) | 13" LCD | 2732×2048 | 264 | 60 Hz | /126472 |

Older iPadOS 16 devices (pre-2021). Simulator identifiers come from [X]. The chips listed are from general knowledge and were **not re-verified** in this pass:
- iPad Pro 9.7 (iPad6,4 [X]; A9X)
- iPad Pro 12.9 1st gen (iPad6,8 [X]; A9X)
- iPad Pro 10.5 (iPad7,3 [X]; A10X)
- iPad Pro 12.9 2nd gen (iPad7,1 [X]; A10X)
- iPad Pro 11 1st gen (iPad8,1 [X]; A12X)
- iPad Pro 12.9 3rd gen (iPad8,5 [X]; A12X)
- iPad Pro 11 2nd gen (iPad8,9 [X]; A12Z)
- iPad Pro 12.9 4th gen (iPad8,12 [X]; A12Z)
- iPad 5th gen (iPad6,12 [X]; A9)
- iPad 6th gen (iPad7,6 [X]; A10)
- iPad 7th gen (iPad7,12 [X]; A10)
- iPad 8th gen (iPad11,7 [X]; A12)
- iPad Air 3 (iPad11,3 [X]; A12)
- iPad Air 4 (iPad13,2 [X]; A14 Bionic [A] /111905, 10.9", 2360×1640, 264 ppi)
- iPad mini 5 (iPad11,1 [X]; A12)

**Gist error to avoid:** the adamawolf gist labels iPad16,3–16,6 as "iPad Pro 11 inch 5th Gen / 12.9 inch 7th Gen". They are actually the **iPad Pro 11-inch (M4) and 13-inch (M4)** ([X] simulator profiles map "iPad Pro 11-inch (M4)" → iPad16,4 and "iPad Pro 13-inch (M4)" → iPad16,6).

## 3. Verification of claims in the app source

### Identifier → name
| Claim in code | Verdict | Correct value |
|---|---|---|
| iPhone16,1 = iPhone 15 Pro | **Correct** | iPhone 15 Pro |
| iPhone16,2 = iPhone 15 Plus | **Wrong** | iPhone 15 Pro Max |
| iPhone15,4 = iPhone 15 Pro | **Wrong** | iPhone 15 |
| iPhone15,5 = iPhone 15 Pro Max | **Wrong** | iPhone 15 Plus |
| iPhone15,2 = iPhone 15 | **Wrong** | iPhone 14 Pro |
| iPhone15,3 = iPhone 15 Plus | **Wrong** | iPhone 14 Pro Max |
| iPhone14,4 = iPhone 14 Pro | **Wrong** | iPhone 13 mini |
| iPhone14,5 = iPhone 14 Pro Max | **Wrong** | iPhone 13 |
| iPhone13,1 = iPhone 13 mini | **Wrong** | iPhone 12 mini |
| iPhone13,2 = iPhone 13 | **Wrong** | iPhone 12 |
| iPhone13,3 = iPhone 13 Pro | **Wrong** | iPhone 12 Pro |
| iPhone13,4 = iPhone 13 Pro Max | **Wrong** | iPhone 12 Pro Max |
| iPhone14,7 = iPhone 14 | **Correct** | iPhone 14 |
| iPhone14,8 = iPhone 14 Plus | **Correct** | iPhone 14 Plus |
| iPhone17,1/2/3/4 = 16 Pro / 16 Pro Max / 16 / 16 Plus | **Correct** | as claimed |

(Missing from the claims: iPhone14,2 = 13 Pro, iPhone14,3 = 13 Pro Max, iPhone14,6 = SE 3, iPhone17,5 = 16e, iPhone18,1–18,5 = 17 Pro / 17 Pro Max / 17 / Air / 17e, iPhone19,2 = 18 Pro, iPhone19,3 and 19,7 = 18 Pro Max.)
Sources: everymac, the adamawolf gist and the Xcode 27 simulator profiles all agree.

### Chip claims
- **A18 Pro Neural Engine = 18-core → WRONG.** It is a **16-core** Neural Engine (Apple /121031 and /121032). No Apple A-series chip has an 18-core NE. The 18 Pro's A20 Pro has a "Dual 16-core" NE.
- **A18 GPU in iPhone 16 → 5-core is CORRECT; 6-core is WRONG** for iPhone 16 and 16 Plus (/121029, /121030). 6-core is the A18 **Pro** (16 Pro). The 16e's A18 is **4-core** (/122208).
- **"A18 Bionic" → WRONG name.** Apple calls it **"A18 chip"** (/121029), and likewise "A18 Pro", "A19", "A19 Pro" and "A20 Pro". "Bionic" applies only through the A16.

### Camera claims
- **iPhone 16 Pro ultra wide 12 MP f/2.2 → WRONG MP.** It is **48MP** Ultra Wide, 13 mm, f/2.2 (/121031). The aperture is right. The 15 Pro had the 12MP f/2.2 UW.
- **Telephoto 3x on 16 Pro vs 5x on 16 Pro Max → WRONG.** **Both** the 16 Pro and 16 Pro Max have a 12MP **5x** Telephoto, 120 mm, f/2.8 (/121031, /121032). The 3x vs 5x split applied to the **15 Pro (3x, 77 mm)** vs **15 Pro Max (5x)**. The 17 Pro and 18 Pro have a 48MP 4x (100 mm) on both sizes.
- **iPhone 16 ultra wide f/2.4 → WRONG.** It is **12MP f/2.2** (/121029). f/2.4 is correct for the iPhone 15/15 Plus and earlier non-Pro models.
- **iPhone 15 Pro front camera 12 MP f/1.9 → CORRECT** (/111829).

### Display claims
- **iPhone 16 / 16 Plus = 458 ppi → WRONG.** Both are **460 ppi** (/121029, /121030).
- **iPhone 15 Plus = 458 ppi → WRONG.** It is **460 ppi** (2796×1290) (/111830). 458 ppi applies only to the 2778×1284 panels: the 12 Pro Max, 13 Pro Max and 14 Plus.
- **iPhone 16 Pro = 6.1" → WRONG.** It is **6.3"** (2622×1206).
- **iPhone 16 Pro Max = 6.7" → WRONG.** It is **6.9"** (2868×1320) (/121031, /121032, and support.apple.com/en-us/108044).

### Metal
- **"Metal 3" → technically correct but outdated.** Apple's support page 102894 (published 2026-03-10) says that **iPhone 12 or later on iOS 26+** supports **Metal 4**. This means every A14-or-newer device in table 1 supports both Metal 3 (iOS 16+) and Metal 4 (iOS 26+). The same page lists Metal 4 iPads on iPadOS 26+ as: iPad Pro 2021 or later, iPad Air 2020 or later, iPad mini 2021 or later, and iPad 2022 or later. Metal 4 is also supported on all Apple-silicon Macs (macOS Tahoe 26+), Apple TV 4K 3rd gen and Vision Pro.
- Metal 3 on iPadOS 16+ covers iPad Pro 11" 3rd gen+, 12.9" 5th gen+, iPad Air 4+, iPad mini 6+ and iPad 9+ (same page). The iPad 9 (A13) supports Metal 3 but is **not** on the Metal 4 list.
- GPU families, from Apple's *Metal Feature Set Tables* PDF (developer.apple.com/metal/Metal-Feature-Set-Tables.pdf, dated May 21, 2026, p.1):

| GPU | Metal version | Apple family |
|---|---|---|
| A13 Bionic | Metal | Apple6 |
| A14 Bionic | Metal 3 & 4 | Apple7 |
| A15 Bionic | Metal 3 & 4 | Apple8 |
| A16 Bionic | Metal 3 & 4 | Apple8 |
| A17 Pro | Metal 3 & 4 | Apple9 |
| A18-series | Metal 3 & 4 | Apple9 |
| A19-series | Metal 3 & 4 | Apple10 |
| M1-series | Metal 3 & 4 | Apple7 |
| M2-series | Metal 3 & 4 | Apple8 |
| M3-series | Metal 3 & 4 | Apple9 |
| M4-series | Metal 3 & 4 | Apple9 |
| M5-series | Metal 3 & 4 | Apple10 |

  - **A20 Pro's GPU family is UNVERIFIED** because the May 2026 table predates it. It presumably supports Metal 3 & 4, but whether it is Apple10 or a new Apple11 could not be confirmed.
  - A13 is listed as plain "Metal" (no Metal 3), which matches the iPad 9 note above. Apple's support page still lists the iPad 9th gen under Metal 3, so these two Apple sources conflict.

## 4. Simulator `SIMULATOR_MODEL_IDENTIFIER`

There is no public Apple documentation for this value. It is taken from the device type's `profile.plist` `modelIdentifier` key. Values below were read [X] from Xcode 27.0's CoreSimulator profiles on this machine:

| Simulator device | modelIdentifier | representedModelIdentifiers |
|---|---|---|
| iPhone 17 | iPhone18,3 | iPhone18,3 |
| iPhone 17 Pro | iPhone18,1 | iPhone18,1 |
| iPhone 17 Pro Max | iPhone18,2 | (not checked) |
| iPhone Air | iPhone18,4 | iPhone18,4 |
| iPhone 17e | iPhone18,5 | iPhone18,5 |
| iPhone 18 Pro | **iPhone19,2** (productClass V63, minRuntime 27.0) | iPhone19,2 |
| iPhone 18 Pro Max | **iPhone19,3** | iPhone19,3, iPhone19,7 |
| iPhone 16e | iPhone17,5 | |
| iPad (A16) | iPad15,7 | |
| iPad Air 11/13 (M4) | iPad16,9 / iPad16,11 | |
| iPad Pro 11/13 (M5) | iPad17,2 / iPad17,4 | |
| iPad mini (A17 Pro) | iPad16,2 | |

Code that maps identifiers should therefore handle **iPhone19,7** (international 18 Pro Max) as well as iPhone19,3.

## 5. Sources (all accessed 2026-10-15)

Apple primary
- Identify your iPhone model: https://support.apple.com/en-us/108044
- iPhone manuals/specs index: https://support.apple.com/en-us/docs/iphone
- iPhone tech specs:
  - 18 Pro https://support.apple.com/en-us/148590
  - 18 Pro Max https://support.apple.com/en-us/148591
  - 17e https://support.apple.com/en-us/126470
  - 17 https://support.apple.com/en-us/125089
  - 17 Pro https://support.apple.com/en-us/125090
  - 17 Pro Max https://support.apple.com/en-us/125091
  - Air https://support.apple.com/en-us/125092
  - 16e https://support.apple.com/en-us/122208
  - 16 https://support.apple.com/en-us/121029
  - 16 Plus https://support.apple.com/en-us/121030
  - 16 Pro https://support.apple.com/en-us/121031
  - 16 Pro Max https://support.apple.com/en-us/121032
  - 15 https://support.apple.com/en-us/111831
  - 15 Plus https://support.apple.com/en-us/111830
  - 15 Pro https://support.apple.com/en-us/111829
  - 15 Pro Max https://support.apple.com/en-us/111828
  - 14 https://support.apple.com/en-us/111850
  - 14 Plus https://support.apple.com/en-us/111854
  - 14 Pro https://support.apple.com/en-us/111849
  - 14 Pro Max https://support.apple.com/en-us/111846
  - SE 3 https://support.apple.com/en-us/111866
  - 13 https://support.apple.com/en-us/111872
  - 13 mini https://support.apple.com/en-us/111873
  - 13 Pro https://support.apple.com/en-us/111871
  - 13 Pro Max https://support.apple.com/en-us/111870
  - 12 https://support.apple.com/en-us/111876
  - 12 mini https://support.apple.com/en-us/111877
  - 12 Pro https://support.apple.com/en-us/111875
  - 12 Pro Max https://support.apple.com/en-us/111874
- iPad tech specs:
  - Air 11 M4 https://support.apple.com/en-us/126471
  - Air 13 M4 https://support.apple.com/en-us/126472
  - iPad A16 https://support.apple.com/en-us/122240
  - Air 11 M3 https://support.apple.com/en-us/122241
  - Air 13 M3 https://support.apple.com/en-us/122242
  - Pro 11 M5 https://support.apple.com/en-us/125406
  - Pro 13 M5 https://support.apple.com/en-us/125407
  - Air 11 M2 https://support.apple.com/en-us/119894
  - Air 13 M2 https://support.apple.com/en-us/119893
  - Pro 11 M4 https://support.apple.com/en-us/119892
  - Pro 13 M4 https://support.apple.com/en-us/119891
  - mini A17 Pro https://support.apple.com/en-us/121456
  - iPad 10 https://support.apple.com/en-us/111840
  - Air 5 https://support.apple.com/en-us/111887
  - Pro 11 4th https://support.apple.com/en-us/111842
  - Pro 12.9 6th https://support.apple.com/en-us/111841
  - iPad 9 https://support.apple.com/en-us/111898
  - mini 6 https://support.apple.com/en-us/111886
  - Pro 11 3rd https://support.apple.com/en-us/111897
  - Pro 12.9 5th https://support.apple.com/en-us/111896
  - Air 4 https://support.apple.com/en-us/111905
- iOS/iPadOS 16 compatible devices: https://support.apple.com/en-us/103267
- Support for Metal on Apple devices: https://support.apple.com/en-us/102894
- Metal Feature Set Tables (PDF): https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf (also via https://developer.apple.com/metal/feature-sets)
- Newsroom:
  - https://www.apple.com/newsroom/2026/09/apple-debuts-iphone-18-pro-and-iphone-18-pro-max/
  - https://www.apple.com/newsroom/2026/03/apple-introduces-iphone-17e/
  - https://www.apple.com/newsroom/2026/03/macbook-neo-iphone-17e-ipad-air-with-m4-and-more-are-now-available/
  - https://www.apple.com/newsroom/2025/09/apple-unveils-iphone-17-pro-and-iphone-17-pro-max/
  - https://www.apple.com/newsroom/2025/09/introducing-iphone-air-a-powerful-new-iphone-with-a-breakthrough-design/
  - https://www.apple.com/newsroom/2025/09/apple-debuts-iphone-17/

Secondary
- everymac identifiers: https://everymac.com/devices/by-identifier/all-iphone-model-identifiers.html
- adamawolf "Apple device identifiers" gist: https://gist.github.com/adamawolf/3048717 (the iPad16,3–6 labels are wrong, see §2)
- The Apple Wiki iPhone 18 Pro Max (iPhone19,3 / 19,7): https://theapplewiki.com/wiki/IPhone_18_Pro_Max (returned 403 to direct fetch; seen only via search snippet)
- NextDNS identifier threads: https://help.nextdns.io/t/x2yjf4m/add-the-iphone-18-pro-series-to-the-device-model-list
- RAM: https://iphonescompare.com/iphone-ram-comparison ; https://9to5mac.com/2023/11/18/iphone-ram-list/ ; Kuo/iPhone 18 RAM rumors https://appleinsider.com/articles/26/06/26/iphone-18-rumored-to-have-slightly-more-ram-might-improve-ai-performance
- Release dates: https://en.wikipedia.org/wiki/List_of_iPhone_models

Local
- Xcode 27.0 CoreSimulator profiles: /Library/Developer/CoreSimulator/Profiles/DeviceTypes/*.simdevicetype/Contents/Resources/profile.plist

## Unverified / caveats
- All iPhone RAM figures are unofficial. The 17e (8 GB) and 18 Pro / Pro Max (12 GB rumored) are unverified.
- The A20 Pro's Metal GPU family is unknown (Apple10 vs Apple11).
- The iPhone 18 Pro (non-Max) international identifier: everymac lists all 18 Pro variants as iPhone19,2. No 19,6 or similar was confirmed.
- iPhone19,1 and iPhone19,4–19,6 are unknown or unreleased (the "iPhone Duo" is pending).
- Release dates for pre-2025 models are secondary (Wikipedia). Apple pages give only the "Year introduced".
- The pre-2021 iPad SoCs in §2 are not re-verified.
