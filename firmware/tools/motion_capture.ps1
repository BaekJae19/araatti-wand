# 완드 동작 녹화
#
#   완드를 USB 로 꽂고 완드 시리얼(#MOTION · #CAL 등)을 줄마다 PC 시각과 함께 파일로 남긴다.
#   동글 · 유니티는 거치지 않는다. 판정을 고친 뒤 실기로 비교할 때 쓴다 (IotPlayerController.md 7-15).
#
#   쓰는 법
#     powershell -ExecutionPolicy Bypass -File motion_capture.ps1 -Port COM13 -Out run.log
#
#   끝나는 때
#     - 동작(#MOTION Horizontal|Vertical|Thrust)이 MinMotions 개 넘게 나온 뒤 IdleSeconds 동안 조용하면
#     - 아무리 길어도 MaxSeconds
#
#   -Raw : 시작할 때 'd', 끝날 때 'D' 를 보내 센서 원값(R 줄)을 같이 녹화한다.
#          ⚠ 펌웨어에 데이터 모으기 모드를 다시 넣었을 때만 쓴다 (지금 저장소 펌웨어에는 없다. 7-15).
#
#   녹화한 파일은 firmware/tools/data/ 에 두고 README 에 순서 · 구간을 적는다.

param(
    [string] $Port        = 'COM13',
    [int]    $MaxSeconds  = 300,
    [int]    $MinMotions  = 20,
    [int]    $IdleSeconds = 25,
    [string] $Out,
    [switch] $Raw
)

$ErrorActionPreference = 'Stop'

$sp = New-Object System.IO.Ports.SerialPort $Port, 115200, 'None', 8, 'One'

# tilt_sign.ps1 과 같다. DTR · RTS 를 건드리면 보드가 리셋된다.
$sp.DtrEnable = $false
$sp.RtsEnable = $false
$sp.Encoding  = [System.Text.Encoding]::UTF8     # 완드 로그에 한글이 섞여 온다
$sp.Open()

$w = New-Object System.IO.StreamWriter($Out, $false, (New-Object System.Text.UTF8Encoding($false)))
$w.AutoFlush = $true

if ($Raw) { $sp.Write('d') }

$watch      = [Diagnostics.Stopwatch]::StartNew()
$buf        = ''
$motions    = 0
$lastMotion = 0.0

try {
    while ($watch.Elapsed.TotalSeconds -lt $MaxSeconds) {
        $buf += $sp.ReadExisting()

        while (($i = $buf.IndexOf("`n")) -ge 0) {
            $line = $buf.Substring(0, $i).TrimEnd("`r")
            $buf  = $buf.Substring($i + 1)
            $t    = $watch.Elapsed.TotalSeconds

            $w.WriteLine(('{0:F3} {1}' -f $t, $line))

            if ($line -match '^#MOTION (Horizontal|Vertical|Thrust)') {
                $motions++
                $lastMotion = $t
            }
        }

        if ($motions -ge $MinMotions -and ($watch.Elapsed.TotalSeconds - $lastMotion) -gt $IdleSeconds) {
            break
        }

        Start-Sleep -Milliseconds 20
    }
}
finally {
    if ($Raw) { try { $sp.Write('D') } catch {} }
    $sp.Close()
    $w.Close()
}

"motions=$motions seconds=$([int]$watch.Elapsed.TotalSeconds)"
