$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$OutDir = Join-Path $PSScriptRoot "..\..\assets\ui\battle_skin"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

function C([int]$r, [int]$g, [int]$b, [int]$a = 255) {
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function New-Bitmap([int]$w, [int]$h, [System.Drawing.Color]$fill) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $b = New-Object System.Drawing.SolidBrush($fill)
    $g.FillRectangle($b, 0, 0, $w, $h)
    $b.Dispose()
    $g.Dispose()
    return $bmp
}

function Save-Png([System.Drawing.Bitmap]$bmp, [string]$name) {
    $path = Join-Path $OutDir $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Set-PixelSafe([System.Drawing.Bitmap]$bmp, [int]$x, [int]$y, [System.Drawing.Color]$color) {
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $bmp.Width -or $y -ge $bmp.Height) { return }
    $bmp.SetPixel($x, $y, $color)
}

function Add-Noise([System.Drawing.Bitmap]$bmp, [int]$amount, [int]$spread = 9) {
    $rand = [System.Random]::new()
    for ($y = 1; $y -lt $bmp.Height - 1; $y++) {
        for ($x = 1; $x -lt $bmp.Width - 1; $x++) {
            if ($rand.Next(100) -ge $amount) { continue }
            $src = $bmp.GetPixel($x, $y)
            $delta = $rand.Next(-$spread, $spread + 1)
            $r = [Math]::Max(0, [Math]::Min(255, $src.R + $delta))
            $g = [Math]::Max(0, [Math]::Min(255, $src.G + $delta))
            $b = [Math]::Max(0, [Math]::Min(255, $src.B + $delta))
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($src.A, $r, $g, $b))
        }
    }
}

function Draw-OrnateFrame([System.Drawing.Bitmap]$bmp, [int]$thickness = 1) {
    $w = $bmp.Width
    $h = $bmp.Height

    # Muted antique-gold palette so lower panels stay dark and readable.
    $outer = C 124 99 62
    $inner = C 84 62 36
    $hi = C 162 132 83
    $shadow = C 34 24 12

    for ($i = 0; $i -lt $thickness; $i++) {
        for ($x = $i; $x -lt $w - $i; $x++) {
            Set-PixelSafe $bmp $x $i $outer
            Set-PixelSafe $bmp $x ($h - 1 - $i) $outer
        }
        for ($y = $i; $y -lt $h - $i; $y++) {
            Set-PixelSafe $bmp $i $y $outer
            Set-PixelSafe $bmp ($w - 1 - $i) $y $outer
        }
    }

    $in = $thickness
    for ($x = $in; $x -lt $w - $in; $x++) {
        Set-PixelSafe $bmp $x $in $hi
        Set-PixelSafe $bmp $x ($h - 1 - $in) $shadow
    }
    for ($y = $in; $y -lt $h - $in; $y++) {
        Set-PixelSafe $bmp $in $y $hi
        Set-PixelSafe $bmp ($w - 1 - $in) $y $shadow
    }

    # Decorative corner flares.
    for ($i = 0; $i -lt 4; $i++) {
        Set-PixelSafe $bmp (1 + $i) 1 $inner
        Set-PixelSafe $bmp 1 (1 + $i) $inner
        Set-PixelSafe $bmp ($w - 2 - $i) 1 $inner
        Set-PixelSafe $bmp ($w - 2) (1 + $i) $inner
        Set-PixelSafe $bmp (1 + $i) ($h - 2) $inner
        Set-PixelSafe $bmp 1 ($h - 2 - $i) $inner
        Set-PixelSafe $bmp ($w - 2 - $i) ($h - 2) $inner
        Set-PixelSafe $bmp ($w - 2) ($h - 2 - $i) $inner
    }

    # Side-center pinstripes.
    if ($w -ge 20) {
        $cx = [int]($w / 2)
        Set-PixelSafe $bmp ($cx - 3) 1 $hi
        Set-PixelSafe $bmp ($cx - 2) 1 $hi
        Set-PixelSafe $bmp ($cx + 1) 1 $hi
        Set-PixelSafe $bmp ($cx + 2) 1 $hi
        Set-PixelSafe $bmp ($cx - 3) ($h - 2) $shadow
        Set-PixelSafe $bmp ($cx - 2) ($h - 2) $shadow
        Set-PixelSafe $bmp ($cx + 1) ($h - 2) $shadow
        Set-PixelSafe $bmp ($cx + 2) ($h - 2) $shadow
    }
}

function Draw-Panel([string]$name, [int]$w, [int]$h, [System.Drawing.Color]$fill, [int]$noise=12, [int]$frameThickness=1) {
    $bmp = New-Bitmap $w $h $fill
    Add-Noise $bmp $noise
    Draw-OrnateFrame $bmp $frameThickness
    Save-Png $bmp $name
}

function Draw-Plaque([string]$name, [int]$w, [int]$h) {
    $bmp = New-Bitmap $w $h (C 17 24 39 232)
    Add-Noise $bmp 16
    Draw-OrnateFrame $bmp 1

    $gold = C 178 146 92
    $dark = C 70 51 25
    $midY = [int]($h / 2)

    for ($y = 6; $y -lt $h - 6; $y++) {
        $leftX = [Math]::Max(1, 8 - [Math]::Abs($midY - $y))
        $rightX = $w - 1 - $leftX
        Set-PixelSafe $bmp $leftX $y $gold
        Set-PixelSafe $bmp ($leftX + 1) $y $dark
        Set-PixelSafe $bmp $rightX $y $gold
        Set-PixelSafe $bmp ($rightX - 1) $y $dark
    }

    Save-Png $bmp $name
}

function Draw-CursorArrow([string]$name) {
    $bmp = New-Bitmap 18 18 (C 0 0 0 0)
    $gold = C 214 183 116
    $shadow = C 78 60 33

    for ($y = 4; $y -le 13; $y++) {
        $len = [int](($y - 4) / 2) + 2
        for ($x = 3; $x -lt 3 + $len; $x++) {
            $bmp.SetPixel($x, $y, $gold)
            if ($x + 1 -lt $bmp.Width) { $bmp.SetPixel($x + 1, $y, $shadow) }
        }
    }

    for ($y = 7; $y -le 10; $y++) {
        for ($x = 10; $x -le 14; $x++) {
            $bmp.SetPixel($x, $y, $gold)
        }
    }

    Save-Png $bmp $name
}

function Draw-Pip([string]$name, [bool]$filled) {
    $bg = if ($filled) { C 224 196 92 } else { C 43 44 56 }
    $bmp = New-Bitmap 10 10 $bg
    Draw-OrnateFrame $bmp 1
    if ($filled) {
        $bmp.SetPixel(3, 3, (C 255 243 176))
        $bmp.SetPixel(4, 3, (C 255 243 176))
        $bmp.SetPixel(3, 4, (C 255 243 176))
    }
    Save-Png $bmp $name
}

function Draw-BarFill([string]$name, [System.Drawing.Color]$left, [System.Drawing.Color]$right) {
    $w = 128
    $h = 14
    $bmp = New-Bitmap $w $h (C 0 0 0 0)

    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $t = [double]$x / [double]($w - 1)
            $r = [int]([Math]::Round($left.R + (($right.R - $left.R) * $t)))
            $g = [int]([Math]::Round($left.G + (($right.G - $left.G) * $t)))
            $b = [int]([Math]::Round($left.B + (($right.B - $left.B) * $t)))
            $bmp.SetPixel($x, $y, (C $r $g $b 255))
        }
    }

    Draw-OrnateFrame $bmp 1
    Save-Png $bmp $name
}

function Draw-Line([string]$name, [int]$w, [int]$h, [System.Drawing.Color]$core, [System.Drawing.Color]$edge) {
    $bmp = New-Bitmap $w $h (C 0 0 0 0)
    if ($w -ge $h) {
        $mid = [int]([Math]::Floor($h / 2))
        for ($x = 0; $x -lt $w; $x++) {
            Set-PixelSafe $bmp $x $mid $core
            if ($mid - 1 -ge 0) { Set-PixelSafe $bmp $x ($mid - 1) $edge }
        }
    } else {
        $mid = [int]([Math]::Floor($w / 2))
        for ($y = 0; $y -lt $h; $y++) {
            Set-PixelSafe $bmp $mid $y $core
            if ($mid - 1 -ge 0) { Set-PixelSafe $bmp ($mid - 1) $y $edge }
        }
    }
    Save-Png $bmp $name
}

function Draw-OrnamentCorner([string]$name, [string]$corner) {
    $bmp = New-Bitmap 16 16 (C 0 0 0 0)
    $gold = C 182 150 95
    $dark = C 84 60 32

    for ($i = 0; $i -lt 7; $i++) {
        switch ($corner) {
            "tl" {
                Set-PixelSafe $bmp $i 0 $gold
                Set-PixelSafe $bmp 0 $i $gold
                if ($i -lt 6) { Set-PixelSafe $bmp ($i + 1) 1 $dark; Set-PixelSafe $bmp 1 ($i + 1) $dark }
            }
            "tr" {
                Set-PixelSafe $bmp (15 - $i) 0 $gold
                Set-PixelSafe $bmp 15 $i $gold
                if ($i -lt 6) { Set-PixelSafe $bmp (14 - $i) 1 $dark; Set-PixelSafe $bmp 14 ($i + 1) $dark }
            }
            "bl" {
                Set-PixelSafe $bmp $i 15 $gold
                Set-PixelSafe $bmp 0 (15 - $i) $gold
                if ($i -lt 6) { Set-PixelSafe $bmp ($i + 1) 14 $dark; Set-PixelSafe $bmp 1 (14 - $i) $dark }
            }
            "br" {
                Set-PixelSafe $bmp (15 - $i) 15 $gold
                Set-PixelSafe $bmp 15 (15 - $i) $gold
                if ($i -lt 6) { Set-PixelSafe $bmp (14 - $i) 14 $dark; Set-PixelSafe $bmp 14 (14 - $i) $dark }
            }
        }
    }

    # Inner knot to increase corner flair.
    switch ($corner) {
        "tl" { Set-PixelSafe $bmp 4 4 $gold; Set-PixelSafe $bmp 5 4 $dark; Set-PixelSafe $bmp 4 5 $dark }
        "tr" { Set-PixelSafe $bmp 11 4 $gold; Set-PixelSafe $bmp 10 4 $dark; Set-PixelSafe $bmp 11 5 $dark }
        "bl" { Set-PixelSafe $bmp 4 11 $gold; Set-PixelSafe $bmp 5 11 $dark; Set-PixelSafe $bmp 4 10 $dark }
        "br" { Set-PixelSafe $bmp 11 11 $gold; Set-PixelSafe $bmp 10 11 $dark; Set-PixelSafe $bmp 11 10 $dark }
    }

    Save-Png $bmp $name
}

# 9-slice panel textures
Draw-Panel "panel_bottom_9slice.png" 64 64 (C 12 18 30 232) 14 2
Draw-Panel "panel_bottom_secondary_9slice.png" 64 64 (C 10 15 25 225) 10 1
Draw-Panel "panel_command_9slice.png" 48 48 (C 13 18 28 236) 9 1
Draw-Panel "panel_party_9slice.png" 48 48 (C 14 19 30 236) 9 1
Draw-Panel "panel_description_9slice.png" 48 48 (C 12 17 27 236) 9 1

# Top bars and center plaque
Draw-Plaque "top_turn_order_9slice.png" 96 32
Draw-Plaque "top_status_9slice.png" 96 28
Draw-Plaque "turn_center_plaque_9slice.png" 220 32

# Row states and badges
Draw-Panel "menu_row_idle_9slice.png" 32 20 (C 16 22 34 210) 6 1
Draw-Panel "menu_row_selected_9slice.png" 32 20 (C 34 32 22 212) 6 1
Draw-Panel "lb_box_9slice.png" 72 24 (C 20 24 35 242) 4 1
Draw-Panel "icon_slot_9slice.png" 20 20 (C 20 24 35 242) 4 1
Draw-Panel "status_chip_9slice.png" 24 16 (C 20 24 35 242) 4 1

# Bars and pips
Draw-BarFill "hp_fill.png" (C 61 191 82) (C 30 126 46)
Draw-BarFill "mp_fill.png" (C 91 141 255) (C 48 90 196)
Draw-Panel "bar_bg_9slice.png" 128 14 (C 26 28 36 246) 4 1
Draw-Pip "pip_full.png" $true
Draw-Pip "pip_empty.png" $false

# Dividers
Draw-Line "divider_h.png" 96 1 (C 100 80 51 130) (C 45 33 19 105)
Draw-Line "divider_v.png" 1 96 (C 100 80 51 130) (C 45 33 19 105)

# Cursor + ornaments
Draw-CursorArrow "cursor_menu_arrow.png"
Draw-OrnamentCorner "ornament_corner_tl.png" "tl"
Draw-OrnamentCorner "ornament_corner_tr.png" "tr"
Draw-OrnamentCorner "ornament_corner_bl.png" "bl"
Draw-OrnamentCorner "ornament_corner_br.png" "br"

$manifest = @"
Battle UI Sprite Pack (generated)

Location:
- assets/ui/battle_skin/

Primary 9-slice textures (recommended patch margins):
- panel_bottom_9slice.png (64x64, margin 12)
- panel_bottom_secondary_9slice.png (64x64, margin 12)
- panel_command_9slice.png (48x48, margin 6)
- panel_party_9slice.png (48x48, margin 6)
- panel_description_9slice.png (48x48, margin 6)
- top_turn_order_9slice.png (96x32, margin 14x10)
- top_status_9slice.png (96x28, margin 14x9)
- turn_center_plaque_9slice.png (220x32, margin 18x10)
- menu_row_idle_9slice.png (32x20, margin 3)
- menu_row_selected_9slice.png (32x20, margin 3)
- lb_box_9slice.png (72x24, margin 5)
- icon_slot_9slice.png (20x20, margin 4)
- status_chip_9slice.png (24x16, margin 4)
- bar_bg_9slice.png (128x14, margin 3)

Element sprites:
- hp_fill.png
- mp_fill.png
- pip_full.png
- pip_empty.png
- divider_h.png
- divider_v.png
- cursor_menu_arrow.png
- ornament_corner_tl.png / tr / bl / br

Intended mapping:
- Top HUD bars -> top_turn_order_9slice, top_status_9slice
- Turn banner -> turn_center_plaque_9slice
- Bottom shell -> panel_bottom_9slice
- Command/Description/Party panels -> command/description/party 9-slice
- Selected command row -> menu_row_selected_9slice
- Resource pips -> pip_full / pip_empty
- LB percent box -> lb_box_9slice
- Menu cursor -> cursor_menu_arrow
"@

Set-Content -Path (Join-Path $OutDir "MANIFEST.txt") -Value $manifest -Encoding UTF8
Write-Output "Generated battle skin assets in: $OutDir"
