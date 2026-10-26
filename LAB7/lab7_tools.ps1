# LAB7 도구.  불러오기(PowerShell 창마다 한 번): iex (Get-Content "$HOME\Documents\lab7\lab7_tools.ps1" -Raw -Encoding UTF8)
$global:L7  = "$HOME\Documents\lab7"
$global:VIV = "C:\AMDDesignTools\2026.1\Vivado\bin"
# 시뮬레이터가 내는 UTF-8 한글을 CP949로 잘못 읽어 깨지는 것 방지 (LAB7 첫 sim7에서 발생)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# 보드 빌드 표: 번호 = (폴더, 최상위, XDC, 비트 이름)
$global:L7map = @{
  '1' = @('lab7_01_spi_rx', 'spi_rx_top', 'constraints/lab7_spi_rx.xdc', 'LAB7-01_spi_rx');
  '2' = @('lab7_02_spi_tx', 'spi_tx_top', 'constraints/lab7_spi_tx.xdc', 'LAB7-02_spi_tx') }
$RX = 'src/spi_slave_rx.v src/spi_uart_log.v src/uart.v src/spi_rx_top.v'
$F2F = '../lab7_01_spi_rx/src/spi_slave_rx.v ../lab7_01_spi_rx/src/spi_uart_log.v ../lab7_01_spi_rx/src/uart.v ../lab7_01_spi_rx/src/spi_rx_top.v ../lab7_02_spi_tx/src/spi_master_tx.v ../lab7_02_spi_tx/src/spi_tx_top.v'
# 시뮬레이션 표: (폴더, 결과 접두어, 추가 define, 파일 목록)
$global:L7sim = @(
  @('lab7_01_spi_rx',  '',      '',     "$RX sim/tb.sv sim/dump.sv"),
  @('lab7_02_spi_tx',  '',      '',     'src/spi_master_tx.v src/spi_uart_log.v src/uart.v src/spi_tx_top.v sim/tb.sv sim/dump.sv'),
  @('lab7_03_spi_f2f', '',      '',     "$F2F sim/tb.sv sim/dump.sv"),
  @('lab7_03_spi_f2f', 'swap_', 'SWAP', "$F2F sim/tb.sv sim/dump.sv") )

function global:sim7([string]$Only = '', [switch]$NoIcarus) {
  # 4개 TB를 Icarus + XSim으로 -> reports\icarus_result.txt, xsim_result.txt (교대는 swap_ 접두어)
  foreach ($s in $L7sim) {
    if ($Only -and $s[0] -notlike "*$Only*") { continue }
    $dir = "$L7\$($s[0])"; $pre = $s[1]; $def = $s[2]; $files = $s[3] -split ' '
    Push-Location $dir
    New-Item -ItemType Directory -Force reports | Out-Null
    $pat = 'PASS|FATAL|Fatal|ERROR|error|  us  | us  |SCK|CS->|클록|바이트|간격'
    if (-not $NoIcarus) {
      $ia = @('-g2012', '-o', "reports\$($pre)icarus.vvp"); if ($def) { $ia += "-D$def" }
      $log = & iverilog @ia @files 2>&1
      if ($LASTEXITCODE -eq 0) { $out = & vvp -n "reports\$($pre)icarus.vvp" 2>&1 } else { $out = $log }
      $keep = $out | ForEach-Object { "$_".Trim() } | Where-Object { $_ -and $_ -notmatch '^VCD info' }
      [IO.File]::WriteAllLines("$dir\reports\$($pre)icarus_result.txt", [string[]]$keep, (New-Object System.Text.UTF8Encoding($false)))
      "== $($s[0]) $pre Icarus";  $keep | Select-String -CaseSensitive 'PASS|FATAL|ERROR|error' | ForEach-Object { "   $_" }
    }
    $snap = "snap_$($pre)tb"
    $xa = @('-sv', '-d', 'XSIM'); if ($def) { $xa += @('-d', $def) }
    $log = & "$VIV\xvlog.bat" @xa @files 2>&1
    $err = $log | Select-String 'ERROR'
    if (-not $err) { $log = & "$VIV\xelab.bat" -s $snap -timescale 1ns/1ps -debug off work.tb work.dump 2>&1; $err = $log | Select-String 'ERROR' }
    if (-not $err) { $out = & "$VIV\xsim.bat" $snap -R 2>&1 } else { $out = $err }
    $keep = $out | Select-String -CaseSensitive -Pattern $pat | ForEach-Object { $_.Line.Trim() }
    [IO.File]::WriteAllLines("$dir\reports\$($pre)xsim_result.txt", [string[]]$keep, (New-Object System.Text.UTF8Encoding($false)))
    "== $($s[0]) $pre XSim"; $keep | Select-String -CaseSensitive 'PASS|FATAL|ERROR|Fatal' | ForEach-Object { "   $_" }
    Pop-Location
  }
}

function global:build7($n) {
  # 보드 비트스트림: build7 1 (과제10·12 수신) | build7 2 (과제11·12 송신)   약 3분, 한 번에 하나만
  $j = $L7map["$n"]; if (-not $j) { "사용법: build7 1|2"; return }
  New-Item -ItemType Directory -Force "$L7\LAB7_bit" | Out-Null
  Push-Location "$L7\$($j[0])"
  $bit = "$L7\LAB7_bit\$($j[3]).bit" -replace '\\','/'
  "== build7 $($j[3])  ($(Get-Date -Format HH:mm:ss))"
  & "$VIV\vivado.bat" -mode batch -nojournal -nolog -source ..\board_build7.tcl -tclargs $j[1] $j[2] $bit 2>&1 |
    Select-String -Pattern 'SYNTH done|IMPL done|UTIL|RESULT|ERROR|CRITICAL WARNING' | ForEach-Object { "   $_" }
  "   끝 ($(Get-Date -Format HH:mm:ss))"
  Pop-Location
}
function global:prog7($n) {
  $j = $L7map["$n"]; if (-not $j) { "사용법: prog7 1|2"; return }
  $bit = "$L7\LAB7_bit\$($j[3]).bit" -replace '\\','/'
  $tcl = "$L7\LAB7_bit\program.tcl" -replace '\\','/'
  "== prog7 $($j[3])"
  & "$VIV\vivado.bat" -mode batch -nojournal -nolog -source $tcl -tclargs $bit 2>&1 |
    Select-String -Pattern "PROGRAM_DONE|ERROR|No hardware|End of startup" | ForEach-Object { "   $_" }
}
function global:rebuild7($n) { build7 $n; if (Select-String -Path "$L7\$($L7map["$n"][0])\reports\board_build_result.txt" -Pattern 'bit=1' -Quiet) { prog7 $n } }
function global:pins7($n) {
  $j = $L7map["$n"]; if (-not $j) { "사용법: pins7 1|2"; return }
  Get-Content "$L7\$($j[0])\$($j[2])" -Encoding UTF8 | Select-String 'PACKAGE_PIN' | ForEach-Object { "   $_" }
}
function global:setpin7($n, $port, $pin) {
  # XDC에서 그 포트 줄만 교체(일치 줄이 정확히 1개일 때만)   예) setpin7 1 spi_sck F8
  $j = $L7map["$n"]; if (-not $j) { "사용법: setpin7 1|2 <포트> <핀>"; return }
  $f = "$L7\$($j[0])\$($j[2])"
  $lines = [IO.File]::ReadAllLines($f)
  $pat = '\[get_ports \{?' + [regex]::Escape($port) + '\}?\]'
  $hit = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'PACKAGE_PIN' -and $lines[$i] -match $pat) {
      "   전: $($lines[$i])"; $lines[$i] = $lines[$i] -replace 'PACKAGE_PIN\s+\S+', "PACKAGE_PIN $pin"; "   후: $($lines[$i])"; $hit++
    }
  }
  if ($hit -ne 1) { "   STOP: '$port' 줄이 $hit 개 (바꾸지 않음)"; return }
  [IO.File]::WriteAllText($f, ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

# ---------- STM32 ----------
function global:Get-StPort { $p = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match 'VID_0483' -and $_.Name -match '\((COM\d+)\)' } | Select-Object -First 1; if ($p -and $p.Name -match '\((COM\d+)\)') { $Matches[1] } }
function global:Get-FpgaPort { $p = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match 'VID_0403' -and $_.Name -match '\((COM\d+)\)' } | Select-Object -First 1; if ($p -and $p.Name -match '\((COM\d+)\)') { $Matches[1] } }
function global:Get-StCli { Get-ChildItem "$env:LOCALAPPDATA\stm32cube\bundles\programmer" -Recurse -Filter STM32_Programmer_CLI.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName }
function global:mcu7($task, [switch]$Flash) {
  # mcu7 task8_tx | task8_cycle | task9_rx   [-Flash]
  $f = "$L7\stm32\$task\ece2_474_routine.c"
  if (-not (Test-Path $f)) { "없음: $f   (task8_tx task8_cycle task9_rx)"; return }
  $dst = "$HOME\Documents\stm32_lab\Core\Src\ece2_474_routine.c"
  Copy-Item $f $dst -Force; (Get-Item $dst).LastWriteTime = Get-Date
  $cmake = "$env:LOCALAPPDATA\stm32cube\bundles\cmake\4.4.0+st.1\bin\cmake.exe"
  $bd = "$HOME\Documents\stm32_lab\build\Debug"
  "== mcu7 $task"
  $out = & $cmake --build $bd 2>&1
  $ok = ($LASTEXITCODE -eq 0)
  $out | Select-String 'error|warning:|Linking' | ForEach-Object { "   $_" }
  if (-not $ok) { "   BUILD FAILED"; $out | Select-Object -Last 15; return }
  $elf = Get-ChildItem $bd -Filter *.elf | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  "   BUILD OK  ELF: $($elf.Name)  $($elf.LastWriteTime.ToString('HH:mm:ss'))"
  if ($Flash) { $cli = Get-StCli; & $cli -c port=SWD -w $elf.FullName -v -rst 2>&1 | Select-String 'verified|Error|error' | ForEach-Object { "   $_" } }
}
function global:listen7([int]$Sec = 5, [switch]$Fpga) {
  # MCU(기본) 또는 FPGA(-Fpga) COM 포트를 Sec초 동안 읽어 출력 (Serial Monitor 대신 텍스트로 받을 때)
  $port = if ($Fpga) { Get-FpgaPort } else { Get-StPort }
  if (-not $port) { "COM 포트 없음"; return }
  $sp = New-Object System.IO.Ports.SerialPort $port, 9600, 'None', 8, 'One'; $sp.Open(); $sp.DiscardInBuffer()
  Start-Sleep $Sec; "== $port ($Sec s) =="; $sp.ReadExisting(); $sp.Close()
}
"LAB7 도구 준비: sim7 [rx|tx|f2f] · build7 1|2 · prog7 1|2 · rebuild7 n · pins7 n · setpin7 n 포트 핀 · mcu7 task8_tx|task8_cycle|task9_rx [-Flash] · listen7 [초] [-Fpga]"
