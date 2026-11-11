# 4단계: 오래 켜두기 확인 (기본 2시간). 진짜 게임을 작은 화면(오른쪽 아래 구석 투명 창)으로 띄우고 1분마다 기록한다.
# 원하면 N분마다 큰 화면에 3초 들어갔다 나온다 (전체 화면 / 창 모드 번갈아): 끝에 -switchEvery N
# 이 창은 그냥 두고 평소처럼 다른 작업을 하면 된다. 끝나면 게임이 저절로 꺼진다.
# 진짜 저장·설정 파일은 안 건드린다 (따로 쓰고 끝나면 지움. 그래서 돈·강수는 0부터 시작).
# 봐야 할 것: 화면이 어두워지거나 작업표시줄이 깨지지 않나 (눈으로)
#            GDI/USER 숫자가 계속 늘지 않나, 메모리가 계속 늘지 않나 (아래 표)
#
# 실행 (PowerShell):
#   powershell -ExecutionPolicy Bypass -File "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\soak_desktop.ps1"
#   (그냥 & "경로.ps1" 로 하면 이 PC 기본 설정이 스크립트 실행을 막아서 오류가 남)
#   (짧게: 위 명령 끝에 -minutes 10 / 10분마다 큰 화면 오가기: 끝에 -switchEvery 10)
param([int]$minutes = 120, [double]$switchEvery = 0)
$proj = Split-Path -Parent $PSScriptRoot
$G = "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe"
Add-Type @"
using System; using System.Runtime.InteropServices;
public class GuiRes { [DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr h, uint flags); }
"@
$userdata = Join-Path $env:APPDATA "Godot\app_userdata\택배 방치형"
$testFiles = @((Join-Path $userdata "test_window_soak.json"), (Join-Path $userdata "test_window_soak.cfg"))
$csv = Join-Path $PSScriptRoot ("soak_" + (Get-Date -Format "yyyyMMdd_HHmm") + ".csv")
$log = Join-Path $env:TEMP "soak_desktop_godot.log"
Remove-Item $log -ErrorAction SilentlyContinue
$args2 = @("--path", "`"$proj`"", "-s", "tests/soak_switch.gd", "--", "--minutes", $minutes, "--switch-every", $switchEvery)
# 콘솔용 실행 파일은 진짜 게임을 자식으로 띄운다 → 게임이 찍은 "PID n"으로 진짜 게임을 잰다
$w = Start-Process -FilePath $G -ArgumentList $args2 -RedirectStandardOutput $log -PassThru -WindowStyle Hidden
$p = $null
for ($i = 0; $i -lt 100 -and -not $p; $i++) {
  Start-Sleep -Milliseconds 200
  if ((Test-Path $log) -and ((Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue) -join "`n") -match "PID (\d+)") { $p = Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue }
}
if (-not $p) { "게임을 못 띄움. 로그: $log"; exit 1 }
Start-Sleep -Seconds 5
$cpu0 = $p.TotalProcessorTime.TotalSeconds; $t0 = Get-Date
"minute,mem_mb,cpu_percent,gdi,user,handles,switches" | Out-File $csv -Encoding utf8
"{0,4} {1,9} {2,7} {3,5} {4,5} {5,7} {6,6}" -f "분", "메모리MB", "CPU%", "GDI", "USER", "핸들", "오간수"
for ($m = 0; $m -le $minutes; $m++) {
  $p.Refresh()
  if ($p.HasExited) { "게임이 꺼짐 (종료 코드 {0}) - {1}분째" -f $p.ExitCode, $m; break }
  $el = ((Get-Date) - $t0).TotalSeconds
  $cpu = if ($el -gt 0) { ($p.TotalProcessorTime.TotalSeconds - $cpu0) / $el / [Environment]::ProcessorCount * 100 } else { 0 }
  $sw = @(Select-String -Path $log -Pattern "^SWITCH" -ErrorAction SilentlyContinue).Count
  $row = @($m, [math]::Round($p.WorkingSet64 / 1MB, 1), [math]::Round($cpu, 2), [GuiRes]::GetGuiResources($p.Handle, 0), [GuiRes]::GetGuiResources($p.Handle, 1), $p.HandleCount, $sw)
  ($row -join ",") | Out-File $csv -Append -Encoding utf8
  "{0,4} {1,9} {2,7} {3,5} {4,5} {5,7} {6,6}" -f $row[0], $row[1], $row[2], $row[3], $row[4], $row[5], $row[6]
  if ($m -lt $minutes) { Start-Sleep -Seconds 60 }
}
if (-not $p.HasExited) { $p.CloseMainWindow() | Out-Null; $p.WaitForExit(5000) | Out-Null; if (-not $p.HasExited) { $p.Kill() } }
$w.WaitForExit(5000) | Out-Null
foreach ($f in $testFiles) { Remove-Item $f -ErrorAction SilentlyContinue }
"기록 파일: $csv"
