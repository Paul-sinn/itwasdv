# 5단계 완료 기준 확인: 투명 창에서 보이는 것만 클릭을 받고, 빈 곳 클릭은 뒤 창으로 넘어가나?
# 진짜 투명 창을 몇 초 띄우고, 점마다 "그 자리를 누르면 어느 창이 받나"를 Windows에 물어본다.
# (마우스를 움직이거나 클릭하지는 않음)
#
# 실행 (PowerShell):
#   & "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\check_desktop.ps1"
$proj = Split-Path -Parent $PSScriptRoot
$G = "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe"
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class HitTest {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr h, uint f);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  public static string TitleAt(int x, int y) {
    POINT p; p.X = x; p.Y = y;
    var t = new StringBuilder(256);
    GetWindowText(GetAncestor(WindowFromPoint(p), 2), t, 256);
    return t.ToString();
  }
}
"@
[HitTest]::SetProcessDpiAwarenessContext([IntPtr]::new(-4)) | Out-Null
$log = Join-Path $env:TEMP "check_desktop_godot.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $G -ArgumentList @("--path", "`"$proj`"", "-s", "tests/check_desktop.gd") -RedirectStandardOutput $log -PassThru -WindowStyle Hidden
function WaitFor($pat) {
  $deadline = (Get-Date).AddSeconds(30)
  while (-not ((Test-Path $log) -and (Select-String -Path $log -Pattern $pat -Quiet)) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 150 }
}
$seen = @{}; $fails = 0; $total = 0
foreach ($phase in @("PHASE1", "PHASE2")) {
  WaitFor "^$phase"
  Start-Sleep -Milliseconds 300
  foreach ($l in (Get-Content $log -Encoding UTF8)) {
    if ($l -match "^PT (\S+) (-?\d+) (-?\d+) (game|behind)" -and -not $seen.ContainsKey($Matches[1])) {
      $seen[$Matches[1]] = $true
      $title = [HitTest]::TitleAt([int]$Matches[2], [int]$Matches[3])
      $isGame = $title -like "택배 방치형*"
      $ok = ($Matches[4] -eq "game") -eq $isGame
      $total++; if (-not $ok) { $fails++ }
      $want = if ($Matches[4] -eq "game") { "게임이 받아야 함" } else { "뒤 창으로 넘어가야 함" }
      "{0} {1,-12} ({2},{3}) {4} → 받은 창: {5}" -f $(if ($ok) { "[통과]" } else { "[실패]" }), $Matches[1], $Matches[2], $Matches[3], $want, $(if ($title) { $title } else { "(바탕화면)" })
    }
  }
}
$p.WaitForExit(20000) | Out-Null
if (-not $p.HasExited) { $p.Kill() }
if ($total -eq 0) { "[실패] 게임 창에서 좌표를 못 받음. 로그: $log"; exit 1 }
"확인 {0}개 중 {1}개 통과" -f $total, ($total - $fails)
if ($fails -eq 0) { "전부 통과"; exit 0 } else { "실패 있음"; exit 1 }
