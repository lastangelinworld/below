$ErrorActionPreference = 'Continue'
Copy-Item 'C:\Users\Антон\Desktop\Godot_v4.7.2-stable_win64.exe' '.\.godot_main.exe' -Force
& '.\.godot_main.exe' --headless --path 'D:\GAME1\below' --import 2>&1 | Out-String -Stream | Where-Object { $_ -match 'ERROR|SCRIPT ERROR|Parse' }
Write-Output '=== IMPORT DONE ==='
