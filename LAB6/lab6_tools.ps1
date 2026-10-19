# LAB6 도구.  불러오기(PowerShell 창마다 한 번): iex (Get-Content "$HOME\Documents\lab6\lab6_tools.ps1" -Raw -Encoding UTF8)
$global:L6  = "$HOME\Documents\lab6"
$global:VIV = "C:\AMDDesignTools\2026.1\Vivado\bin"
# 보드 빌드 표: 번호 = (폴더, 최상위, XDC, 비트 이름)
$global:L6map = @{
  '1' = @('lab6_01_servo',    'servo_board_top', 'constraints/lab6_servo.xdc',     'LAB6-01_servo');
  '2' = @('lab6_02_sram',     'sram_board_top',  'constraints/lab6_sram.xdc',      'LAB6-02_sram');
  '3' = @('lab6_03_dac',      'dac_board_top',   'constraints/lab6_dac.xdc',       'LAB6-03_dac');
  '4' = @('lab6_04_uart_cmd', 'uart_cmd_top',    'constraints/lab6_uart_cmd.xdc',  'LAB6-04_uart_cmd') }
# XSim 표: (폴더, 결과 파일 접두어, 파일 목록)
$global:L6sim = @(
  @('lab6_01_servo',    '',       'src/servo_ctrl.v src/servo_position.v src/servo_pwm.v sim/tb.sv sim/dump.sv'),
  @('lab6_01_servo',    'board_', 'src/btn_onepulse.v src/servo_position.v src/servo_pwm_board.v src/servo_board_top.v sim/tb_board.sv sim/dump_board.sv'),
  @('lab6_02_sram',     '',       'src/sram.v src/sram_bus_control.v sim/tb.sv sim/dump.sv'),
  @('lab6_02_sram',     'board_', 'src/sram.v src/sram_bus_control.v src/sram_board_top.v sim/async_sram_model.sv sim/tb_board.sv sim/dump_board.sv'),
  @('lab6_03_dac',      '',       'src/dac.v src/dac_parallel8.v src/ramp8.v sim/tb.sv sim/dump.sv'),
  @('lab6_03_dac',      'board_', 'src/dac.v src/dac_parallel8.v src/ramp8.v src/dac_board_top.v sim/ad7302_model.sv sim/tb_board.sv sim/dump_board.sv'),
  @('lab6_04_uart_cmd', '',       'src/uart.v src/uart_cmd_top.v sim/tb.sv sim/dump.sv') )

function global:sim6([string]$Only = '') {
  # 7개 TB를 XSim으로 실행 -> reports\xsim_result.txt / board_xsim_result.txt, 파형 reports\*xsim_wave.vcd
  foreach ($s in $L6sim) {
    if ($Only -and $s[0] -notlike "*$Only*") { continue }
    $dir = "$L6\$($s[0])"; $pre = $s[1]; $files = $s[2] -split ' '
    Push-Location $dir
    New-Item -ItemType Directory -Force reports | Out-Null
    $snap = "snap_$($pre)tb"
    $log = & "$VIV\xvlog.bat" -sv -d XSIM @files 2>&1
    $err = $log | Select-String 'ERROR'
    if (-not $err) { $log = & "$VIV\xelab.bat" -s $snap -timescale 1ns/1ps -debug off work.tb work.dump 2>&1; $err = $log | Select-String 'ERROR' }
    if (-not $err) { $out = & "$VIV\xsim.bat" $snap -R 2>&1 } else { $out = $err }
    $keep = $out | Select-String -CaseSensitive -Pattern 'PASS|FATAL|Fatal|ERROR|^CLASS|^BOARD|PC\(FPGA|violation|\$finish' | ForEach-Object { $_.Line.Trim() }
    [IO.File]::WriteAllLines("$dir\reports\$($pre)xsim_result.txt", [string[]]$keep, (New-Object System.Text.UTF8Encoding($false)))
    "== $($s[0]) $(if($pre){'board'}else{'class'})"; $keep | ForEach-Object { "   $_" }
    Pop-Location
  }
}

function global:synth6 {
  # 수업·보드 최상위 7개를 합성만 해서 LUT/FF/IOB 기록 (약 5분)
  Push-Location $L6
  "== synth6  ($(Get-Date -Format HH:mm:ss))"
  & "$VIV\vivado.bat" -mode batch -nojournal -nolog -source synth_all.tcl 2>&1 | Select-String -Pattern ' : ' | ForEach-Object { "   $_" }
  Pop-Location
}

function global:build6($n) {
  # 보드 비트스트림: build6 1|3|4  (2 SRAM은 SRAM 핀 입력 뒤)
  $j = $L6map["$n"]; if (-not $j) { "사용법: build6 1|2|3|4"; return }
  New-Item -ItemType Directory -Force "$L6\LAB6_bit" | Out-Null
  Push-Location "$L6\$($j[0])"
  $bit = "$L6\LAB6_bit\$($j[3]).bit" -replace '\\','/'
  "== build6 $($j[3])  ($(Get-Date -Format HH:mm:ss))"
  & "$VIV\vivado.bat" -mode batch -nojournal -nolog -source ..\board_build6.tcl -tclargs $j[1] $j[2] $bit 2>&1 |
    Select-String -Pattern 'SYNTH done|IMPL done|UTIL|RESULT|ERROR|CRITICAL WARNING' | ForEach-Object { "   $_" }
  Pop-Location
}

function global:prog6($n) {
  $j = $L6map["$n"]; if (-not $j) { "사용법: prog6 1|2|3|4"; return }
  $bit = "$L6\LAB6_bit\$($j[3]).bit" -replace '\\','/'
  $tcl = "$L6\LAB6_bit\program.tcl" -replace '\\','/'
  "== prog6 $($j[3])"
  & "$VIV\vivado.bat" -mode batch -nojournal -nolog -source $tcl -tclargs $bit 2>&1 |
    Select-String -Pattern "PROGRAM_DONE|ERROR|No hardware|End of startup" | ForEach-Object { "   $_" }
}
function global:rebuild6($n) { build6 $n; if (Select-String -Path "$L6\$($L6map["$n"][0])\reports\board_build_result.txt" -Pattern 'bit=1' -Quiet) { prog6 $n } }

function global:pins6($n) {
  $j = $L6map["$n"]; if (-not $j) { "사용법: pins6 1|2|3|4"; return }
  Get-Content "$L6\$($j[0])\$($j[2])" | Select-String 'PACKAGE_PIN' | ForEach-Object { "   $_" }
}

function global:setpin6($n, $port, $pin) {
  # XDC에서 그 포트 줄만 교체(일치 줄이 정확히 1개일 때만). 없으면 새 줄 추가는 하지 않음.
  $j = $L6map["$n"]; if (-not $j) { "사용법: setpin6 1|2|3|4 <포트> <핀>   예) setpin6 4 mcu_rxd F8"; return }
  $f = "$L6\$($j[0])\$($j[2])"
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

# ---------- STM32 ----------
function global:Get-StPort { $p = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match 'VID_0483' -and $_.Name -match '\((COM\d+)\)' } | Select-Object -First 1; if ($p -and $p.Name -match '\((COM\d+)\)') { $Matches[1] } }
function global:Get-FpgaPort { $p = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -notmatch 'VID_0483' -and $_.Name -match '\((COM\d+)\)' } | Select-Object -First 1; if ($p -and $p.Name -match '\((COM\d+)\)') { $Matches[1] } }
function global:Get-StCli { Get-ChildItem "$env:LOCALAPPDATA\stm32cube\bundles\programmer" -Recurse -Filter STM32_Programmer_CLI.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName }
function global:mcu6($task, [switch]$Flash) {
  # mcu6 task5        : 빌드만(보드 없이 컴파일 확인)
  # mcu6 task5 -Flash : 빌드 + 보드에 올리기
  $f = "$L6\stm32\$task\ece2_474_routine.c"
  if (-not (Test-Path $f)) { "없음: $f   (ex1 ex2 task5 task6 task7)"; return }
  $dst = "$HOME\Documents\stm32_lab\Core\Src\ece2_474_routine.c"
  Copy-Item $f $dst -Force; (Get-Item $dst).LastWriteTime = Get-Date
  $cmake = "$env:LOCALAPPDATA\stm32cube\bundles\cmake\4.4.0+st.1\bin\cmake.exe"
  $bd = "$HOME\Documents\stm32_lab\build\Debug"
  "== mcu6 $task"
  $out = & $cmake --build $bd 2>&1
  $ok = ($LASTEXITCODE -eq 0)
  $out | Select-String 'error|warning:|Linking' | ForEach-Object { "   $_" }
  if (-not $ok) { "   BUILD FAILED"; $out | Select-Object -Last 15; return }
  $elf = Get-ChildItem $bd -Filter *.elf | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  "   BUILD OK  ELF: $($elf.Name)  $($elf.LastWriteTime.ToString('HH:mm:ss'))"
  $size = Get-ChildItem "$env:LOCALAPPDATA\stm32cube\bundles\gnu-tools-for-stm32" -Recurse -Filter arm-none-eabi-size.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  if ($size) { & $size $elf.FullName | ForEach-Object { "   $_" } }
  if ($Flash) {
    $cli = Get-StCli
    & $cli -c port=SWD -w $elf.FullName -v -rst 2>&1 | Select-String 'verified|Error|error' | ForEach-Object { "   $_" }
  }
}
function global:talk6([string]$text, [switch]$Both) {
  # MCU VCP로 문자를 한 글자씩 보내고(0.3 s 간격) 응답을 읽는다. -Both: FPGA USB-UART 포트도 함께 읽음.
  $mcu = Get-StPort; if (-not $mcu) { "MCU COM 포트 없음"; return }
  $sp = New-Object System.IO.Ports.SerialPort $mcu, 9600, 'None', 8, 'One'; $sp.Encoding = [Text.Encoding]::UTF8; $sp.Open(); $sp.DiscardInBuffer()
  $fp = $null
  if ($Both) { $fc = Get-FpgaPort; if ($fc) { $fp = New-Object System.IO.Ports.SerialPort $fc, 9600, 'None', 8, 'One'; $fp.Open(); $fp.DiscardInBuffer() } else { "FPGA COM 포트 없음" } }
  foreach ($c in $text.ToCharArray()) { $sp.Write([string]$c); Start-Sleep -Milliseconds 300 }
  Start-Sleep 1
  "== MCU ($mcu) =="; $sp.ReadExisting(); $sp.Close()
  if ($fp) { $b = New-Object byte[] 256; $k = 0; while ($fp.BytesToRead -gt 0 -and $k -lt 256) { $b[$k] = [byte]$fp.ReadByte(); $k++ }
    "== FPGA ($fc) ==  $k 바이트: " + (($b[0..([Math]::Max($k-1,0))] | Select-Object -First $k | ForEach-Object { '0x{0:X2}' -f $_ }) -join ' '); $fp.Close() }
}
"LAB6 도구 준비: sim6 [sram] · synth6 · build6 n · prog6 n · rebuild6 n · pins6 n · setpin6 n '포트' 핀 · mcu6 task5 [-Flash] · talk6 '1Aa' [-Both]"
