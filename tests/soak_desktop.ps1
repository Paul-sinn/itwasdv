# 5단계: 오래 켜두기 확인 (기본 2시간). 진짜 게임을 투명 창으로 띄우고 1분마다 기록한다.
# 이 창은 그냥 두고 평소처럼 다른 작업을 하면 된다. 끝나면 게임이 저절로 꺼진다.
# 봐야 할 것: 화면이 어두워지거나 작업표시줄이 깨지지 않나 (눈으로)
#            GDI/USER 숫자가 계속 늘지 않나, 메모리가 계속 늘지 않나 (아래 표)
#
# 실행 (PowerShell):
#   & "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\soak_desktop.ps1"
#   (짧게: 위 명령 끝에 -minutes 10)
param([int]$minutes = 120)
$proj = Split-Path -Parent $PSScriptRoot
$G = "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe"
Add-Type @"
using System; using System.Runtime.InteropServices;
public class GuiRes { [DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr h, uint flags); }
"@
$csv = Join-Path $PSScriptRoot ("soak_" + (Get-Date -Format "yyyyMMdd_HHmm") + ".csv")
$p = Start-Process -FilePath $G -ArgumentList @("--path", "`"$proj`"") -PassThru
Start-Sleep -Seconds 5
$cpu0 = $p.TotalProcessorTime.TotalSeconds; $t0 = Get-Date
"minute,mem_mb,cpu_percent,gdi,user,handles" | Out-File $csv -Encoding utf8
"{0,4} {1,9} {2,7} {3,5} {4,5} {5,7}" -f "분", "메모리MB", "CPU%", "GDI", "USER", "핸들"
for ($m = 0; $m -le $minutes; $m++) {
  $p.Refresh()
  if ($p.HasExited) { "게임이 꺼짐 (종료 코드 {0}) - {1}분째" -f $p.ExitCode, $m; break }
  $el = ((Get-Date) - $t0).TotalSeconds
  $cpu = if ($el -gt 0) { ($p.TotalProcessorTime.TotalSeconds - $cpu0) / $el / [Environment]::ProcessorCount * 100 } else { 0 }
  $row = @($m, [math]::Round($p.WorkingSet64 / 1MB, 1), [math]::Round($cpu, 2), [GuiRes]::GetGuiResources($p.Handle, 0), [GuiRes]::GetGuiResources($p.Handle, 1), $p.HandleCount)
  ($row -join ",") | Out-File $csv -Append -Encoding utf8
  "{0,4} {1,9} {2,7} {3,5} {4,5} {5,7}" -f $row[0], $row[1], $row[2], $row[3], $row[4], $row[5]
  if ($m -lt $minutes) { Start-Sleep -Seconds 60 }
}
if (-not $p.HasExited) { $p.CloseMainWindow() | Out-Null; Start-Sleep -Seconds 3; if (-not $p.HasExited) { $p.Kill() } }
"기록 파일: $csv"
