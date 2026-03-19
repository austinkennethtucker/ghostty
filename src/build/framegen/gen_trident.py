#!/usr/bin/env python3
"""Generate 235 frames of the Trident logo animation.

Draws the Trident app icon as clean geometric ASCII art using polygon
rasterization, then animates with a gentle pulsing glow effect.
"""

import math
import os
import re

WIDTH = 100
HEIGHT = 41
NUM_FRAMES = 235
CX = 49.5  # center x


def fill_polygon(grid, polygon, ch='@'):
    """Fill a polygon on the grid using scanline rasterization."""
    if not polygon:
        return
    # Find row bounds
    min_row = max(0, int(min(p[1] for p in polygon)))
    max_row = min(HEIGHT - 1, int(max(p[1] for p in polygon)))

    for row in range(min_row, max_row + 1):
        y = row + 0.5
        # Find x intersections
        intersections = []
        n = len(polygon)
        for i in range(n):
            x1, y1 = polygon[i]
            x2, y2 = polygon[(i + 1) % n]
            if y1 == y2:
                continue
            if min(y1, y2) <= y < max(y1, y2):
                x = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
                intersections.append(x)

        intersections.sort()
        # Fill between pairs
        for i in range(0, len(intersections) - 1, 2):
            left = max(0, int(intersections[i]))
            right = min(WIDTH - 1, int(intersections[i + 1]))
            for c in range(left, right + 1):
                grid[row][c] = ch


def make_diamond(cx, cy, hw, hh):
    """Create a diamond polygon centered at (cx, cy) with half-width hw and half-height hh."""
    return [
        (cx, cy - hh),      # top
        (cx + hw, cy),       # right
        (cx, cy + hh),       # bottom
        (cx - hw, cy),       # left
    ]


def make_angled_rect(x1, y1, x2, y2, half_width):
    """Create an angled rectangle (parallelogram) from (x1,y1) to (x2,y2) with given half-width."""
    dx = x2 - x1
    dy = y2 - y1
    length = math.sqrt(dx * dx + dy * dy)
    if length == 0:
        return []
    # Normal vector perpendicular to the line
    nx = -dy / length * half_width
    ny = dx / length * half_width
    return [
        (x1 + nx, y1 + ny),
        (x2 + nx, y2 + ny),
        (x2 - nx, y2 - ny),
        (x1 - nx, y1 - ny),
    ]


def build_trident():
    """Build the trident shape matching the app logo."""
    grid = [[' '] * WIDTH for _ in range(HEIGHT)]

    # --- CENTER PRONG ---
    # Arrow tip: diamond at top
    fill_polygon(grid, make_diamond(CX, 3.0, 4.0, 3.5))
    # Shaft: narrow rectangle down to crossguard
    fill_polygon(grid, make_angled_rect(CX, 5.5, CX, 20.0, 1.8))

    # --- LEFT PRONG ---
    # Tip position: angled outward-left
    ltip_x = CX - 16
    ltip_y = 8.0
    # Arrow tip
    fill_polygon(grid, make_diamond(ltip_x, ltip_y, 3.5, 3.0))
    # Shaft: angled from tip down-inward to crossguard area
    lshaft_end_x = CX - 5.5
    lshaft_end_y = 20.0
    fill_polygon(grid, make_angled_rect(ltip_x, ltip_y + 2.5, lshaft_end_x, lshaft_end_y, 1.6))

    # --- RIGHT PRONG ---
    rtip_x = CX + 16
    rtip_y = 8.0
    fill_polygon(grid, make_diamond(rtip_x, rtip_y, 3.5, 3.0))
    rshaft_end_x = CX + 5.5
    rshaft_end_y = 20.0
    fill_polygon(grid, make_angled_rect(rtip_x, rtip_y + 2.5, rshaft_end_x, rshaft_end_y, 1.6))

    # --- CROSSGUARD (diamond where prongs converge) ---
    fill_polygon(grid, make_diamond(CX, 21.5, 10.0, 3.5))

    # --- LOWER SHAFT (tapers to a point) ---
    # Upper part: wider
    fill_polygon(grid, [
        (CX - 3.5, 24.0),
        (CX + 3.5, 24.0),
        (CX + 2.5, 31.0),
        (CX - 2.5, 31.0),
    ])
    # Lower part: tapers to point
    fill_polygon(grid, [
        (CX - 2.5, 31.0),
        (CX + 2.5, 31.0),
        (CX + 0.8, 38.0),
        (CX - 0.8, 38.0),
    ])
    # Final point
    fill_polygon(grid, [
        (CX - 0.8, 37.5),
        (CX + 0.8, 37.5),
        (CX, 39.5),
    ])

    return grid


def add_aura(grid):
    """Add a single-cell glow around the trident."""
    marks = set()
    for row in range(HEIGHT):
        for col in range(WIDTH):
            if grid[row][col] == '@':
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
    """Check if a filled cell is on the edge."""
    if grid[row][col] != '@':
        return False
    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        nr, nc = row + dr, col + dc
        if not (0 <= nr < HEIGHT and 0 <= nc < WIDTH):
            return True
        if grid[nr][nc] != '@':
            return True
    return False


def render_frame(grid, edge_map, frame):
    """Render a frame with a pulsing glow animation.

    The animation is a gentle breathing pulse: edges and aura glow
    brighter and dimmer in a smooth sine wave cycle.
    """
    lines = []

    # Pulse: smooth sine wave, ~3 second cycle at 30fps = 90 frames
    pulse = (math.sin(2 * math.pi * frame / 90) + 1) / 2  # 0.0 to 1.0

    # Secondary slower pulse for the aura
    aura_pulse = (math.sin(2 * math.pi * frame / 140) + 1) / 2

    for row in range(HEIGHT):
        parts = []
        in_span = False

        for col in range(WIDTH):
            ch = grid[row][col]

            should_blue = False
            if ch == '·':
                # Aura glows with the pulse
                should_blue = aura_pulse > 0.3
            elif ch == '@':
                if edge_map[row][col]:
                    # Edges always glow
                    should_blue = True
                else:
                    # Interior pulses: at peak, more of the body glows
                    should_blue = pulse > 0.6

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
            f"Line {i}: expected {WIDTH} chars, got {len(line)}: '{line[:20]}...'"


def main():
    frames_dir = os.path.join(os.path.dirname(__file__), 'trident_frames')
    os.makedirs(frames_dir, exist_ok=True)

    for f in os.listdir(frames_dir):
        if f.endswith('.txt'):
            os.remove(os.path.join(frames_dir, f))

    print("Building trident shape...")
    grid = build_trident()
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
