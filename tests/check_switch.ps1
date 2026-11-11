# 2단계 완료 기준 (창 쪽): 진짜 창으로 작은 화면 <-> 큰 화면 오가기
#   큰 화면 "전체 화면" 방식 100번 + "창 모드" 방식 100번 + 큰 화면에 있는 동안 방식 바꾸기 20번 (tests/check_switch.gd)
# 확인하는 것:
#   - 매번: 창 크기·위치·모드·투명·항상 위·테두리·클릭 통과 (Godot 안에서)
#   - 25번마다: Windows가 아는 진짜 창 크기·위치·테두리·항상 위 (여기서 Windows에 물어봄)
#   - 끝나고: 메모리·GDI·USER·핸들이 늘지 않았나 (여기서)
# 30초쯤 주 모니터가 깜빡인다 (큰 화면이 덮었다 사라짐). 마우스·키보드는 안 건드림.
# 진짜 저장·설정 파일은 안 건드림.
#
# 실행 (PowerShell):
#   powershell -ExecutionPolicy Bypass -File "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\check_switch.ps1"
#   (화면이 깨지지 않았나 눈으로 보려면 끝에 -shots "<빈 폴더>": 25번마다 화면을 찍어 PNG로 남김)
param([string]$shots = "")
$proj = Split-Path -Parent $PSScriptRoot
$G = "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe"
# 늘어난 것을 "늘었다"고 볼 기준 (warm → end, 그 사이 220번 오감)
# 메모리는 작업 메모리(ws_mb)로 본다. private_mb는 그래픽 드라이버가 창 크기에 따라 잡았다 놓는 몫이 섞여서
# 같은 상태에서도 100MB 넘게 오르내린다 (2026-11-10 실측) → 참고로만 보여줌
$MAX_GDI = 2; $MAX_USER = 2; $MAX_HANDLES = 30; $MAX_MEM_MB = 10
Add-Type @"
using System; using System.Runtime.InteropServices;
public class SwitchW32 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr h, uint flags);
}
"@
[SwitchW32]::SetProcessDpiAwarenessContext([IntPtr]::new(-4)) | Out-Null
Add-Type -AssemblyName System.Drawing   # 전체 화면 맨 위 줄 확인에도 씀
if ($shots) { New-Item -ItemType Directory -Force $shots | Out-Null }
function Shot($name, $x, $y, $w, $h, $scale) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size $w, $h)); $g.Dispose()
  $out = New-Object System.Drawing.Bitmap ([int]($w * $scale)), ([int]($h * $scale))
  $g2 = [System.Drawing.Graphics]::FromImage($out); $g2.DrawImage($bmp, 0, 0, $out.Width, $out.Height); $g2.Dispose(); $bmp.Dispose()
  $out.Save((Join-Path $shots "$name.png")); $out.Dispose()
}
$log = Join-Path $env:TEMP "check_switch_godot.log"
Remove-Item $log, "$log.err" -ErrorAction SilentlyContinue
# 콘솔용 실행 파일은 진짜 게임을 자식으로 띄운다 → 게임이 찍은 "PID n"으로 진짜 게임을 잰다
$p = Start-Process -FilePath $G -ArgumentList @("--path", "`"$proj`"", "-s", "tests/check_switch.gd") -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden
# 핸들을 먼저 한 번 읽어 둔다: 안 그러면 HasExited로만 기다렸을 때 ExitCode가 비어서(PowerShell 5.1) 다 통과해도 실패로 나옴
$null = $p.Handle
$gp = $null; $done = 0; $samples = @(); $winFails = 0; $winTotal = 0; $summary = ""; $godotFails = @()
$deadline = (Get-Date).AddSeconds(240)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 40
  $lines = @(if (Test-Path $log) { Get-Content $log -Encoding UTF8 })
  for (; $done -lt $lines.Count; $done++) {
    $l = $lines[$done]
    if ($l -match "^PID (\d+)") { $gp = Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue }
    elseif ($l -match "^SAMPLE (\S+) (.*)$" -and $gp) {
      $gp.Refresh()
      $samples += [pscustomobject]@{
        tag = $Matches[1]; private_mb = [math]::Round($gp.PrivateMemorySize64 / 1MB, 1); ws_mb = [math]::Round($gp.WorkingSet64 / 1MB, 1)
        gdi = [SwitchW32]::GetGuiResources($gp.Handle, 0); user = [SwitchW32]::GetGuiResources($gp.Handle, 1); handles = $gp.HandleCount; godot = $Matches[2] }
    }
    elseif ($l -match "^WIN (\S+) (\d+) (\S+) (-?\d+) (-?\d+) (\d+) (\d+)") {
      $tag = $Matches[1]; $h = [IntPtr]::new([long]$Matches[2]); $what = $Matches[3]
      $x = [int]$Matches[4]; $y = [int]$Matches[5]; $w = [int]$Matches[6]; $hh = [int]$Matches[7]
      $r = New-Object SwitchW32+RECT; [SwitchW32]::GetWindowRect($h, [ref]$r) | Out-Null
      $style = [SwitchW32]::GetWindowLong($h, -16); $ex = [SwitchW32]::GetWindowLong($h, -20)
      $top = ($ex -band 0x8) -ne 0; $caption = ($style -band 0x00C00000) -eq 0x00C00000; $sizable = ($style -band 0x00040000) -ne 0
      switch ($what) {
        "small" { $ok = $r.L -eq $x -and $r.T -eq $y -and ($r.R - $r.L) -eq $w -and ($r.B - $r.T) -eq $hh -and $top -and -not $caption
                  $seen = "창 ({0},{1}) {2}x{3}" -f $r.L, $r.T, ($r.R - $r.L), ($r.B - $r.T) }
        # 전체 화면 = 테두리 없는 보통 창, 모니터보다 위아래 1픽셀씩 큼 (desktop_window.gd 맨 위 설명).
        # 모니터 맨 위 줄이 정말 게임으로 덮였나도 본다 (전에는 맨 위 2줄로 바탕화면이 보였음)
        "full"  { $ok = $r.L -eq $x -and $r.T -eq $y -and ($r.R - $r.L) -eq $w -and ($r.B - $r.T) -eq $hh -and -not $top -and -not $caption
                  $line = New-Object System.Drawing.Bitmap $w, 2; $gl = [System.Drawing.Graphics]::FromImage($line)
                  $gl.CopyFromScreen($x, $y + 1, 0, 0, (New-Object System.Drawing.Size $w, 2)); $gl.Dispose()
                  $notBg = 0; for ($ly = 0; $ly -lt 2; $ly++) { for ($lx = 0; $lx -lt $w; $lx += 4) { $c = $line.GetPixel($lx, $ly); if (-not ($c.R -eq 33 -and $c.G -eq 38 -and $c.B -eq 48)) { $notBg++ } } }
                  $line.Dispose()
                  if ($notBg -gt 0) { $ok = $false }
                  $seen = "창 ({0},{1}) {2}x{3}, 모니터 맨 위 2줄 중 배경색 아닌 점 {4}개" -f $r.L, $r.T, ($r.R - $r.L), ($r.B - $r.T), $notBg }
        "window" { $c = New-Object SwitchW32+RECT; [SwitchW32]::GetClientRect($h, [ref]$c) | Out-Null
                   $pt = New-Object SwitchW32+POINT; [SwitchW32]::ClientToScreen($h, [ref]$pt) | Out-Null
                   $ok = $pt.X -eq $x -and $pt.Y -eq $y -and $c.R -eq $w -and $c.B -eq $hh -and -not $top -and $caption -and $sizable
                   $seen = "안쪽 ({0},{1}) {2}x{3}, 테두리 {4}, 크기 조절 {5}" -f $pt.X, $pt.Y, $c.R, $c.B, $caption, $sizable }
      }
      if ($shots) {
        if ($what -eq "small") { Shot $tag ($x - 60) ($y - 60) ($w + 120) ($hh + 120) 1.0 }
        elseif ($what -eq "full") { Shot $tag $x $y $w $hh 0.4 }
        else { Shot $tag ($r.L - 20) ($r.T - 20) ($r.R - $r.L + 40) ($r.B - $r.T + 40) 0.5 }
      }
      $winTotal++; if (-not $ok) { $winFails++ }
      "{0} Windows 창 {1,-10} 기대 ({2},{3}) {4}x{5} → {6}, 항상 위 {7}" -f $(if ($ok) { "[통과]" } else { "[실패]" }), $tag, $x, $y, $w, $hh, $seen, $top
    }
    elseif ($l -match "^\[실패\]") { $godotFails += $l; $l }
    elseif ($l -match "^확인 \d+개 중") { $summary = $l }
    elseif ($l -match "^---") { $l }
  }
  $p.Refresh()
  if ($p.HasExited -and $done -ge $lines.Count) { break }
}
if (-not $p.HasExited) { "[실패] 시간 안에 안 끝남 → 끔"; $p.Kill(); if ($gp -and -not $gp.HasExited) { $gp.Kill() } }

""
"메모리·화면 자원 (SAMPLE마다):"
$samples | Format-Table tag, private_mb, ws_mb, gdi, user, handles, godot -AutoSize | Out-String -Width 200
$bad = 0
$warm = $samples | Where-Object tag -eq "warm"; $end = $samples | Where-Object tag -eq "end"
if ($warm -and $end) {
  $d = [pscustomobject]@{ gdi = $end.gdi - $warm.gdi; user = $end.user - $warm.user; handles = $end.handles - $warm.handles; mem = [math]::Round($end.ws_mb - $warm.ws_mb, 1); priv = [math]::Round($end.private_mb - $warm.private_mb, 1) }
  "warm → end 늘어난 양: GDI {0} (기준 {1} 이하), USER {2} (기준 {3} 이하), 핸들 {4} (기준 {5} 이하), 작업 메모리 {6}MB (기준 {7}MB 이하), private {8}MB (참고)" -f $d.gdi, $MAX_GDI, $d.user, $MAX_USER, $d.handles, $MAX_HANDLES, $d.mem, $MAX_MEM_MB, $d.priv
  if ($d.gdi -gt $MAX_GDI -or $d.user -gt $MAX_USER -or $d.handles -gt $MAX_HANDLES -or $d.mem -gt $MAX_MEM_MB) { "[실패] 오갈수록 늘어남"; $bad++ } else { "[통과] 오가도 늘지 않음" }
} else { "[실패] 메모리를 못 잼 (게임 PID를 못 받음?) 로그: $log"; $bad++ }
"Windows 쪽 창 확인 {0}개 중 {1}개 통과" -f $winTotal, ($winTotal - $winFails)
if ($winTotal -eq 0) { "[실패] Windows 쪽 창 확인을 못 함"; $bad++ }
if ($summary) { "Godot 안 확인: $summary" } else { "[실패] Godot 쪽 결과가 없음. 로그: $log"; $bad++ }
if ($p.ExitCode -ne 0) { "[실패] 게임 종료 코드 [$($p.ExitCode)] (0이어야 함)" }
if ($bad -eq 0 -and $winFails -eq 0 -and $godotFails.Count -eq 0 -and $p.ExitCode -eq 0) { "전부 통과"; exit 0 } else { "실패 있음"; exit 1 }
