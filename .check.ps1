$ErrorActionPreference = 'Continue'
Copy-Item 'C:\Users\Антон\Desktop\Godot_v4.7.2-stable_win64.exe' '.\.godot_main.exe' -Force
& '.\.godot_main.exe' --headless --path 'D:\GAME1\below' --import 2>&1 | Out-String -Stream | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Failed loading' }
Write-Output '--- import done ---'
foreach ($t in @('smoke_fist_combat','smoke_player_anim','smoke_poise','smoke_craft','smoke_skills')) {
  $res = & '.\.godot_main.exe' --headless --path 'D:\GAME1\below' "res://tests/$t.tscn" 2>&1 | Out-String
  ($res -split "`n") | Where-Object { $_ -match 'RESULT|FAIL|SCRIPT ERROR' }
}
