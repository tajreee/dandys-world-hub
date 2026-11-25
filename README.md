# DW Authorized Test Hub — modular prototype

Refactor dari prototype sebelumnya. Hanya untuk experience Roblox milik sendiri atau lingkungan pengujian yang diizinkan. Tidak diuji terhadap game publik Dandy's World; tidak ada injector, bypass, atau implementasi baru untuk mekanisme internal game tersebut.

## Struktur
- `src/Hub.client.lua`: composition root, lifecycle, heartbeat, cleanup.
- `src/core/Config.lua`: toggle, tag, warna, interval, radius.
- `src/core/Registry.lua`: discovery objek, status dan seleksi target.
- `src/utils/Movement.lua`: perpindahan pada map uji dengan pemeriksaan landing.
- `src/utils/Interaction.lua`: state prompt dan retry.
- `src/features/Automation.lua`: prioritas automation.
- `src/features/Evade.lua`: seleksi safe point.
- `src/features/Tracker.lua`: marker dan cleanup.
- `src/features/Monitor.lua`: stamina, floor, skill-check monitor.
- `src/ui/Interface.lua`: GUI dan toggle.

## Penggunaan di Roblox Studio
Pilihan sederhana: salin `dist/dandys_world_modular.lua` ke LocalScript dalam `StarterPlayer > StarterPlayerScripts` dan Play. Tidak perlu hosting. Untuk source modular, gunakan Rojo dengan `default.project.json` atau buat struktur Folder/ModuleScript yang sama seperti `src` di StarterPlayerScripts; `Hub.client.lua` menjadi LocalScript dan lainnya ModuleScript.

## Build ulang
Dari root proyek: `python tools/build.py` (Python 3, tanpa dependensi eksternal). Output adalah `dist/dandys_world_modular.lua`. Ubah modul source, bukan file dist. Jangan jalankan versi bundle dan versi modular bersamaan.

## Kontrak map uji
Tambahkan tag CollectionService `DW_Machine`, `DW_Twisted`, `DW_Capsule`, `DW_Item`, `DW_Elevator`, dan `DW_SafePoint` ke Model/BasePart yang sesuai. Gunakan atribut `Progress` (0..1), `Completed`, `Collected`, `Stamina`, `Floor`, dan `SkillCheckActive` seperti prototype. Interaksi memerlukan ProximityPrompt yang enabled dan handler game uji yang benar-benar mengubah status. Script tidak menciptakan handler tersebut. Safe point perlu area landing dengan permukaan dan clearance yang sesuai. Skill check hanya monitor. Automation default OFF; prioritas Evade > prompt aktif > Elevator (jika mesin selesai) > Research > Machine.

## Verifikasi
Build dan konsistensi struktur diperiksa secara lokal. Runtime Roblox Studio belum diuji; tag, atribut, server validation dan prompt tetap bergantung pada map pengujian. Tidak ada klaim kompatibilitas dengan game publik. Perubahan kecil lifecycle: koneksi tombol stop ikut dikelola; marker dibersihkan ketika karakter tidak aktif; monitor toleran terhadap karakter nil.
