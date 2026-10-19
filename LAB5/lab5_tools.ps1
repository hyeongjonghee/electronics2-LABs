# LAB5 실험 당일 도구.  불러오기: iex (Get-Content "$HOME\Documents\lab5\lab5_tools.ps1" -Raw -Encoding UTF8)
$global:L5 = "$HOME\Documents\lab5"
$global:L5map = @{
  '1' = @('lab5_01_piano',   'lab5_piano_board',   'piano',             'constraints/lab5_piano.xdc',   'LAB5-01_piano');
  '2' = @('lab5_02_traffic', 'lab5_traffic_board', 'traffic_board_top', 'constraints/lab5_traffic.xdc', 'LAB5-02_traffic');
  '3' = @('lab5_03_adc',     'lab5_adc_board',     'adc_board_top',     'constraints/lab5_adc.xdc',     'LAB5-03_adc') }

function global:prog5($n) {
  $j = $L5map["$n"]; if (-not $j) { "사용법: prog5 1|2|3"; return }
  $bit = "$L5\LAB5_bit\$($j[4]).bit" -replace '\\','/'
  $tcl = "$L5\LAB5_bit\program.tcl" -replace '\\','/'
  "== prog5 $($j[4])"
  & "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -nojournal -nolog -source $tcl -tclargs $bit 2>&1 |
    Select-String -Pattern "PROGRAM_DONE|ERROR|No hardware|End of startup" | ForEach-Object { "   $_" }
}

function global:pins5($n) {
  $j = $L5map["$n"]; if (-not $j) { "사용법: pins5 1|2|3"; return }
  Get-Content "$L5\$($j[0])\$($j[3])" | Select-String 'PACKAGE_PIN' | ForEach-Object { "   $_" }
}

function global:setpin($n, $port, $pin) {
  $j = $L5map["$n"]; if (-not $j) { "사용법: setpin 1|2|3 <포트> <핀>   예) setpin 1 'key[7]' K4"; return }
  $f = "$L5\$($j[0])\$($j[3])"
  $lines = [IO.File]::ReadAllLines($f)
  $pat = '\[get_ports \{?' + [regex]::Escape($port) + '\}?\]'
  $hit = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'PACKAGE_PIN' -and $lines[$i] -match $pat) {
      "   전: $($lines[$i])"
      $lines[$i] = $lines[$i] -replace 'PACKAGE_PIN\s+\S+', "PACKAGE_PIN $pin"
      "   후: $($lines[$i])"; $hit++
    }
  }
  if ($hit -ne 1) { "   STOP: '$port' 줄이 $hit 개 (바꾸지 않음)"; return }
  [IO.File]::WriteAllText($f, ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function global:rebuild5($n) {
  $j = $L5map["$n"]; if (-not $j) { "사용법: rebuild5 1|2|3"; return }
  Push-Location "$L5\$($j[0])"
  "== rebuild5 $($j[4])  ($(Get-Date -Format HH:mm:ss))"
  & "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -nojournal -nolog -source ..\board_build.tcl -tclargs $j[1] $j[2] $j[3] 2>&1 |
    Select-String -Pattern 'SYNTH status|IMPL status|RESULT|ERROR|CRITICAL WARNING' | ForEach-Object { "   $_" }
  $bit = ".\vivado_board\$($j[1]).runs\impl_1\$($j[2]).bit"
  $ok = (Test-Path $bit) -and ((Get-Item $bit).LastWriteTime -gt (Get-Date).AddMinutes(-15))
  if ($ok) { Copy-Item $bit "$L5\LAB5_bit\$($j[4]).bit" -Force; "   -> LAB5_bit\$($j[4]).bit" } else { "   새 비트스트림 없음 (위 ERROR 확인)" }
  Pop-Location
  if ($ok) { prog5 $n }
}

function global:Get-StPort { $p = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match 'VID_0483' -and $_.Name -match '\((COM\d+)\)' } | Select-Object -First 1; if ($p -and $p.Name -match '\((COM\d+)\)') { $Matches[1] } }
function global:Get-StCli { Get-ChildItem "$env:LOCALAPPDATA\stm32cube\bundles\programmer" -Recurse -Filter STM32_Programmer_CLI.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName }
function global:Read-Serial($com, [scriptblock]$action) { $sp = New-Object System.IO.Ports.SerialPort $com, 9600, 'None', 8, 'One'; $sp.Open(); $sp.DiscardInBuffer(); & $action; Start-Sleep 3; $t = $sp.ReadExisting(); $sp.Close(); "== Serial ($com) =="; $t }
function global:run5($n) {
  $d = if ("$n" -match '^\d+$') { "stm32_task$n" } else { "stm32_$n" }
  $f = "$L5\$d\ece2_474_routine.c"
  if (-not (Test-Path $f)) { "없음: $f   (run5 3 | run5 4 | run5 ex1 | run5 ex2 | run5 ex3)"; return }
  $dst = "$HOME\Documents\stm32_lab\Core\Src\ece2_474_routine.c"
  Copy-Item $f $dst -Force; (Get-Item $dst).LastWriteTime = Get-Date
  $cmake = "$env:LOCALAPPDATA\stm32cube\bundles\cmake\4.4.0+st.1\bin\cmake.exe"
  $bd = "$HOME\Documents\stm32_lab\build\Debug"
  "== run5 $d"
  $out = & $cmake --build $bd 2>&1
  $ok = ($LASTEXITCODE -eq 0)
  $out | Select-String 'error|warning|Linking|no work' | ForEach-Object { "   $_" }
  if (-not $ok) { "   BUILD FAILED"; $out | Select-Object -Last 15; return }
  $elf = Get-ChildItem $bd -Filter *.elf | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  "   ELF: $($elf.Name)  $($elf.LastWriteTime.ToString('HH:mm:ss'))"
  $com = Get-StPort; if (-not $com) { $com = 'COM4' }
  $cli = Get-StCli
  Read-Serial $com { & $cli -c port=SWD -w $elf.FullName -v -rst 2>&1 | Select-String 'verified|Error|error' | ForEach-Object { "   $_" } }
}
"LAB5 도구 준비: run5 ex1|ex2|ex3|3|4 · prog5 1|2|3 · pins5 1|2|3 · setpin n '포트' 핀 · rebuild5 n"