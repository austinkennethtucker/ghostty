#!/usr/bin/env python3
"""Generate 235 frames of a trident ASCII art animation with shimmer effect.

Each frame is 100 chars wide x 41 lines tall, using the same character set and
<span class="b"> markup as the original ghost animation.

The trident matches the angular Trident app logo: three sharp arrow-tipped
prongs, a diamond crossguard, and a tapered blade shaft.
"""

import math
import os
import re

WIDTH = 100
HEIGHT = 41
NUM_FRAMES = 235

# The trident ASCII art matching the app logo geometry.
# Three arrow-tipped prongs, diamond crossguard, tapered shaft.
# Each line padded to 100 chars by parse_art().
TRIDENT_ART = r"""
                                               @
                                              $@$
                                             $$@$$
                                            $$$@$$$
                                           $$$$@$$$$
                                            $$$@$$$
                                             $$@$$
                    @                        $$@$$                        @
                   $@$                       $$@$$                       $@$
                  $$@$$                      $$@$$                      $$@$$
                 $$$@$$$                     $$@$$                     $$$@$$$
                $$$$@$$$$                    $$@$$                    $$$$@$$$$
                 $$$@$$$                     $$@$$                     $$$@$$$
                  $$@$                       $$@$$                       $@$$
                   $@$                       $$@$$                       $@$
                    $$                       $$@$$                       $$
                     $$                      $$@$$                      $$
                      $$                     $$@$$                     $$
                       $$                   $$$@$$$                   $$
                        $$$               $$$$@@@$$$$               $$$
                         $$$$           $$$$$@@@@@$$$$$           $$$$
                          $$$$$$$   $$$$$$$$$@@@@@$$$$$$$$$   $$$$$$$
                           $$$$$$$$$$$$$$$$$$@@@@@$$$$$$$$$$$$$$$$$$$
                             $$$$$$$$$$$$$$$$$@@@$$$$$$$$$$$$$$$$$
                               $$$$$$$$$$$$$$@@@@@$$$$$$$$$$$$$$
                                  $$$$$$$$$$$@@@$$$$$$$$$$
                                      $$$$$$@@@@@$$$$$$
                                          $$@@@@@$$
                                          $$$@@@$$$
                                          $$$@@@$$$
                                          $$$@@@$$$
                                           $$@@@$$
                                           $$@@@$$
                                           $$@@@$$
                                            $@@@$
                                            $@@@$
                                             $@$
                                             $@$
                                              @
                                              @
""".strip('\n')


def parse_art():
    """Parse the ASCII art into a 2D grid."""
    lines = TRIDENT_ART.split('\n')
    grid = []
    for line in lines:
        if len(line) < WIDTH:
            line = line + ' ' * (WIDTH - len(line))
        elif len(line) > WIDTH:
            line = line[:WIDTH]
        grid.append(list(line))

    while len(grid) < HEIGHT:
        grid.append([' '] * WIDTH)
    grid = grid[:HEIGHT]
    return grid


def add_aura(grid):
    """Add a faint glow around trident edges."""
    marks = set()
    for row in range(HEIGHT):
        for col in range(WIDTH):
            if grid[row][col] != ' ':
                for dr in [-1, 0, 1]:
                    for dc in [-1, 0, 1]:
                        if dr == 0 and dc == 0:
                            continue
                        nr, nc = row + dr, col + dc
                        if 0 <= nr < HEIGHT and 0 <= nc < WIDTH:
                            if grid[nr][nc] == ' ':
                                marks.add((nr, nc))
    for r, c in marks:
        grid[r][c] = '·'


def is_edge(grid, row, col):
    """Check if a non-space cell is on the edge of the trident."""
    if grid[row][col] == ' ' or grid[row][col] == '·':
        return False
    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        nr, nc = row + dr, col + dc
        if not (0 <= nr < HEIGHT and 0 <= nc < WIDTH):
            return True
        if grid[nr][nc] == ' ' or grid[nr][nc] == '·':
            return True
    return False


def path_position(row, col, grid):
    """Map a cell to its position along the trident's path (0.0=bottom, 1.0=tips)."""
    cx = WIDTH // 2

    # Bottom shaft point (rows 38-40)
    if row >= 38:
        return (40 - row) / 45.0

    # Shaft (rows 27-37)
    if row >= 27:
        return 0.04 + (37 - row) / 35.0

    # Crossguard / convergence (rows 19-26)
    if row >= 19:
        return 0.35 + (26 - row) / 25.0

    # Prongs (rows 0-18)
    if row < 19:
        base = 0.63 + (18 - row) / 30.0
        dist_from_center = abs(col - cx)
        horiz_delay = dist_from_center / 250.0
        return base - horiz_delay

    return 0.5


def wave_intensity(row, col, frame, grid):
    """Calculate blue energy intensity at this position for this frame."""
    ch = grid[row][col]
    if ch == ' ':
        return 0.0

    pos = path_position(row, col, grid)

    cycle_length = 80
    wave_width = 0.16

    total = 0.0
    for wave_offset in [0.0, 0.5]:
        wave_center = ((frame / cycle_length) + wave_offset) % 1.0
        dist = abs(pos - wave_center)
        dist = min(dist, abs(pos - wave_center + 1.0), abs(pos - wave_center - 1.0))

        if dist < wave_width:
            intensity = 1.0 - (dist / wave_width)
            intensity = intensity ** 0.6
            total = max(total, intensity)

    return min(1.0, total)


def render_frame(grid, edge_map, frame):
    """Render a single frame with span markup."""
    lines = []

    for row in range(HEIGHT):
        parts = []
        in_span = False

        for col in range(WIDTH):
            ch = grid[row][col]
            wi = wave_intensity(row, col, frame, grid)
            is_e = edge_map[row][col]

            should_blue = False
            if ch == '·':
                should_blue = wi > 0.25
            elif is_e:
                should_blue = True
            elif ch != ' ':
                should_blue = wi > 0.4

            if should_blue and not in_span:
                parts.append('<span class="b">')
                in_span = True
            elif not should_blue and in_span:
                parts.append('</span>')
                in_span = False

            parts.append(ch)

        if in_span:
            parts.append('</span>')

        lines.append(''.join(parts))

    return '\n'.join(lines) + '\n'


def verify_frame(frame_str):
    """Verify frame dimensions."""
    clean = re.sub(r'</?span[^>]*>', '', frame_str)
    lines = clean.split('\n')
    if lines and lines[-1] == '':
        lines = lines[:-1]

    assert len(lines) == HEIGHT, f"Expected {HEIGHT} lines, got {len(lines)}"
    for i, line in enumerate(lines):
        assert len(line) == WIDTH, \
            f"Line {i}: expected {WIDTH} chars, got {len(line)}"


def main():
    frames_dir = os.path.join(os.path.dirname(__file__), 'trident_frames')
    os.makedirs(frames_dir, exist_ok=True)

    for f in os.listdir(frames_dir):
        if f.endswith('.txt'):
            os.remove(os.path.join(frames_dir, f))

    print("Building trident shape...")
    grid = parse_art()
    add_aura(grid)

    edge_map = [[False] * WIDTH for _ in range(HEIGHT)]
    for r in range(HEIGHT):
        for c in range(WIDTH):
            edge_map[r][c] = is_edge(grid, r, c)

    print(f"Generating {NUM_FRAMES} frames...")
    for i in range(NUM_FRAMES):
        frame_str = render_frame(grid, edge_map, i)
        verify_frame(frame_str)

        filename = f"frame_{i+1:03d}.txt"
        filepath = os.path.join(frames_dir, filename)
        with open(filepath, 'w') as f:
            f.write(frame_str)

        if (i + 1) % 50 == 0:
            print(f"  Generated {i+1}/{NUM_FRAMES} frames")

    print(f"Done! {NUM_FRAMES} frames in {frames_dir}")


if __name__ == '__main__':
    main()
