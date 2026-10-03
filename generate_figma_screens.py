"""
Generate high-fidelity SVG wireframes for OpenAamps application.
Screens:
1. Home & Live Concert Arena
2. Now Playing (Audiophile Codec Badge in Player Only)
3. Equalizer & 8D Studio DSP (AMOLED dark, 270-deg Rotary Dial 0-100% strict clamping)
4. Search & Deep Learning Hum-to-Song Recognition (STFT Spectrogram, 128-d Embedding, Cosine Vector Search)
5. Library & WebDAV Personal Cloud Storage (Clean layout, disconnected status inside box)
6. Live Concert Arena & Stadium Ticket Pass Booking (Virtual Stage + Physical Stadium NFC/QR Passes)
"""

def generate_svg():
    w = 3000
    h = 1060
    
    # Color palette
    bg_canvas = "#050508"
    phone_bg = "#0B0B10"
    card_bg = "#13131A"
    card_border = "#20202E"
    accent = "#3D5AFE"
    accent_glow = "#536DFE"
    cyan = "#00E5FF"
    green = "#00E676"
    text_primary = "#FFFFFF"
    text_secondary = "#8E8EA8"
    text_muted = "#55556E"
    
    svg = []
    svg.append(f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" xmlns="http://www.w3.org/2000/svg">')
    
    # Common definitions: gradients, clip paths, filters
    svg.append('<defs>')
    svg.append('  <linearGradient id="phoneGrad" x1="0" y1="0" x2="0" y2="1">')
    svg.append('    <stop offset="0%" stop-color="#0E0E15"/>')
    svg.append('    <stop offset="100%" stop-color="#07070A"/>')
    svg.append('  </linearGradient>')
    
    svg.append('  <linearGradient id="concertHeroGrad" x1="0" y1="0" x2="1" y2="1">')
    svg.append('    <stop offset="0%" stop-color="#28154D"/>')
    svg.append('    <stop offset="100%" stop-color="#120A24"/>')
    svg.append('  </linearGradient>')

    svg.append('  <linearGradient id="accentGrad" x1="0" y1="0" x2="1" y2="1">')
    svg.append('    <stop offset="0%" stop-color="#3D5AFE"/>')
    svg.append('    <stop offset="100%" stop-color="#2979FF"/>')
    svg.append('  </linearGradient>')

    svg.append('  <linearGradient id="albumArtGrad" x1="0" y1="0" x2="1" y2="1">')
    svg.append('    <stop offset="0%" stop-color="#B71C1C"/>')
    svg.append('    <stop offset="50%" stop-color="#4A0E17"/>')
    svg.append('    <stop offset="100%" stop-color="#1A0508"/>')
    svg.append('  </linearGradient>')

    svg.append('  <linearGradient id="ticketFoilGrad" x1="0" y1="0" x2="1" y2="1">')
    svg.append('    <stop offset="0%" stop-color="#302060"/>')
    svg.append('    <stop offset="50%" stop-color="#1A1035"/>')
    svg.append('    <stop offset="100%" stop-color="#0E0820"/>')
    svg.append('  </linearGradient>')

    svg.append('  <linearGradient id="spectrogramGrad" x1="0" y1="0" x2="1" y2="0">')
    svg.append('    <stop offset="0%" stop-color="#00E5FF"/>')
    svg.append('    <stop offset="35%" stop-color="#3D5AFE"/>')
    svg.append('    <stop offset="70%" stop-color="#FF1744"/>')
    svg.append('    <stop offset="100%" stop-color="#FFD600"/>')
    svg.append('  </linearGradient>')

    svg.append('  <clipPath id="screenClip">')
    svg.append('    <rect width="393" height="852" rx="44" ry="44"/>')
    svg.append('  </clipPath>')
    svg.append('</defs>')

    # Canvas Background
    svg.append(f'<rect width="{w}" height="{h}" fill="{bg_canvas}"/>')

    # Top Master Canvas Header
    svg.append('<g transform="translate(60, 36)">')
    svg.append('  <text x="0" y="24" fill="#FFFFFF" font-family="Inter, -apple-system, sans-serif" font-size="22" font-weight="700" letter-spacing="1.5">OPENAAMPS ARCHITECTURE &amp; HIGH-FIDELITY SYSTEM DESIGN</text>')
    svg.append('  <text x="0" y="46" fill="#8E8EA8" font-family="Inter, -apple-system, sans-serif" font-size="12" font-weight="500">PRODUCTION AUDIOPHILE ARCHITECTURE - AMOLED DARK DSP STUDIO - DEEP LEARNING MELODY RETRIEVAL - TICKET ARENA</text>')
    svg.append('</g>')

    # Helper for Phone Chassis Frame
    def draw_phone_chassis(x, y, title, subtitle):
        res = []
        # Header text above phone
        res.append(f'<g transform="translate({x}, {y - 45})">')
        res.append(f'  <text x="0" y="16" fill="#3D5AFE" font-family="Inter, -apple-system, sans-serif" font-size="11" font-weight="700" letter-spacing="1">{title.upper()}</text>')
        res.append(f'  <text x="0" y="32" fill="#FFFFFF" font-family="Inter, -apple-system, sans-serif" font-size="15" font-weight="600">{subtitle}</text>')
        res.append('</g>')

        # Phone chassis with border glow
        res.append(f'<g transform="translate({x}, {y})">')
        res.append(f'  <rect width="393" height="852" rx="44" ry="44" fill="url(#phoneGrad)" stroke="#222232" stroke-width="3"/>')
        
        # Clip group for screen contents
        res.append('  <g clip-path="url(#screenClip)">')
        
        # Dynamic Island / Camera pill
        res.append('    <rect x="134" y="11" width="125" height="30" rx="15" fill="#000000"/>')
        res.append('    <circle cx="240" cy="26" r="5" fill="#14141E"/>')
        
        # Status Bar elements
        res.append('    <text x="36" y="32" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="600">9:41</text>')
        # Battery, wifi, 5g indicators
        res.append('    <g transform="translate(325, 23)">')
        res.append('      <path d="M0,8 L3,8 L3,3 L0,3 Z M5,8 L8,8 L8,1 L5,1 Z M10,8 L13,8 L13,0 L10,0 Z" fill="#FFFFFF"/>')
        res.append('      <rect x="18" y="1" width="20" height="9" rx="2.5" fill="none" stroke="#FFFFFF" stroke-width="1.2"/>')
        res.append('      <rect x="20" y="3" width="13" height="5" rx="1" fill="#00E676"/>')
        res.append('    </g>')

        # Home Indicator pill at bottom
        res.append('    <rect x="126" y="836" width="141" height="4" rx="2" fill="#444458"/>')

        return "\n".join(res)

    def close_phone():
        return "  </g>\n</g>"

    # Helper for Bottom Navigation Bar
    def draw_navbar(active_index=0):
        tabs = ["Home", "Search", "Concerts", "Library", "Settings"]
        icons = [
            "M3,9 L12,2 L21,9 L21,20 L15,20 L15,14 L9,14 L9,20 L3,20 Z", # Home
            "M15.5,14 L20,18.5 M10,16 A6,6 0 1,1 16,10 A6,6 0 0,1 10,16 Z", # Search
            "M4,6 L20,6 L18,18 L6,18 Z M2,10 L22,10", # Concerts / Stage
            "M4,4 L16,4 L16,18 L4,18 Z M8,2 L20,2 L20,15", # Library
            "M12,15 A3,3 0 1,0 12,9 A3,3 0 0,0 12,15 Z M19.4,15 L19.4,9 L17,9 L12,2 L7,9 L4.6,9" # Settings
        ]
        res = []
        res.append('    <!-- Bottom Navigation Bar -->')
        res.append('    <rect x="0" y="770" width="393" height="82" fill="#09090D" opacity="0.96"/>')
        res.append('    <line x1="0" y1="770" x2="393" y2="770" stroke="#1A1A24" stroke-width="1"/>')
        
        spacing = 393 / 5
        for i, name in enumerate(tabs):
            cx = spacing * i + spacing / 2
            is_active = (i == active_index)
            color = accent if is_active else text_muted
            font_wt = "700" if is_active else "500"
            res.append(f'    <g transform="translate({cx - 10}, 780)">')
            res.append(f'      <path d="{icons[i]}" fill="none" stroke="{color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>')
            res.append(f'      <text x="10" y="27" fill="{color}" font-family="Inter, sans-serif" font-size="9" font-weight="{font_wt}" text-anchor="middle">{name}</text>')
            if is_active:
                res.append(f'      <circle cx="10" cy="34" r="2" fill="{accent}"/>')
            res.append('    </g>')
        return "\n".join(res)

    # =========================================================================
    # SCREEN 1: HOME & LIVE CONCERT ARENA
    # =========================================================================
    s1 = []
    s1.append(draw_phone_chassis(60, 140, "Screen 01", "Home & Live Concert Arena"))
    
    # App Bar
    s1.append('    <!-- App Bar -->')
    s1.append('    <g transform="translate(20, 56)">')
    s1.append('      <text x="0" y="22" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="18" font-weight="800" letter-spacing="0.5">OPENAAMPS</text>')
    # Persistent session indicator
    s1.append('      <rect x="135" y="6" width="138" height="22" rx="11" fill="#141420" stroke="#252538" stroke-width="1"/>')
    s1.append('      <circle cx="146" cy="17" r="4" fill="#00E676"/>')
    s1.append('      <text x="156" y="21" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="9" font-weight="600">SESSION PERSISTENT</text>')
    # Pi-AAMPS sync Cast icon & Notification
    s1.append('      <g transform="translate(320, 6)">')
    s1.append('        <rect width="30" height="24" rx="6" fill="#141420"/>')
    s1.append('        <path d="M5,17 L25,17 L25,7 L5,7 Z M8,17 A4,4 0 0,0 5,14 M12,17 A8,8 0 0,0 5,10" fill="none" stroke="#FFFFFF" stroke-width="1.4"/>')
    s1.append('      </g>')
    s1.append('    </g>')

    # Live Concert Arena Hero Card
    s1.append('    <!-- Live Concert Arena Hero Banner -->')
    s1.append('    <g transform="translate(20, 100)">')
    s1.append('      <rect width="353" height="154" rx="20" fill="url(#concertHeroGrad)" stroke="#382268" stroke-width="1.5"/>')
    s1.append('      <rect x="16" y="16" width="158" height="20" rx="10" fill="#3D5AFE" fill-opacity="0.25" stroke="#3D5AFE" stroke-width="1"/>')
    s1.append('      <circle cx="26" cy="26" r="3.5" fill="#00E5FF"/>')
    s1.append('      <text x="35" y="30" fill="#00E5FF" font-family="Inter, sans-serif" font-size="9" font-weight="700" letter-spacing="0.5">LIVE CONCERT ARENA</text>')
    s1.append('      <text x="16" y="62" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="18" font-weight="700">Coldplay: Spheres Tour</text>')
    s1.append('      <text x="16" y="80" fill="#B0A8D0" font-family="Inter, sans-serif" font-size="11">Dual Experience: 3D Virtual Dome or Stadium Ticket Passes</text>')
    # CTA Buttons
    s1.append('      <g transform="translate(16, 98)">')
    s1.append('        <rect width="148" height="38" rx="12" fill="#3D5AFE"/>')
    s1.append('        <text x="74" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="700" text-anchor="middle">Enter Virtual Stage</text>')
    s1.append('      </g>')
    s1.append('      <g transform="translate(174, 98)">')
    s1.append('        <rect width="162" height="38" rx="12" fill="#1E1636" stroke="#483675" stroke-width="1"/>')
    s1.append('        <text x="81" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="600" text-anchor="middle">Book Stadium Pass</text>')
    s1.append('      </g>')
    s1.append('    </g>')

    # Keep Listening - Verified Artist Circular Portraits (No song artwork fallback!)
    s1.append('    <!-- Keep Listening: Verified Artist Headshots -->')
    s1.append('    <g transform="translate(20, 274)">')
    s1.append('      <text x="0" y="16" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="15" font-weight="700">Keep Listening</text>')
    s1.append('      <text x="353" y="16" fill="#3D5AFE" font-family="Inter, sans-serif" font-size="11" font-weight="600" text-anchor="end">See all</text>')
    
    artists = [
        ("The Weeknd", "#E53935", "#8E0000"),
        ("Billie Eilish", "#00B0FF", "#004777"),
        ("Coldplay", "#7C4DFF", "#38006B"),
        ("Taylor Swift", "#FFB300", "#FF6F00"),
        ("Dua Lipa", "#E040FB", "#7B1FA2")
    ]
    for i, (name, c1, c2) in enumerate(artists):
        ax = i * 72
        s1.append(f'      <g transform="translate({ax}, 32)">')
        s1.append(f'        <circle cx="28" cy="28" r="28" fill="{c2}" stroke="#2A2A3E" stroke-width="2"/>')
        s1.append(f'        <circle cx="28" cy="28" r="26" fill="{c1}" fill-opacity="0.4"/>')
        s1.append(f'        <text x="28" y="33" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="700" text-anchor="middle">{name[0]}</text>')
        s1.append(f'        <circle cx="48" cy="48" r="7" fill="#00E676" stroke="#0B0B10" stroke-width="1.8"/>')
        s1.append(f'        <text x="28" y="70" fill="#D0D0E0" font-family="Inter, sans-serif" font-size="9" font-weight="500" text-anchor="middle">{name.split()[0]}</text>')
        s1.append('      </g>')
    s1.append('    </g>')

    # Quick Picks Section (Strictly NO Codec Badge here! Clean layout)
    s1.append('    <!-- Quick Picks: Clean Track Rows (No Codec Badges) -->')
    s1.append('    <g transform="translate(20, 390)">')
    s1.append('      <text x="0" y="16" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="15" font-weight="700">Quick Picks</text>')
    s1.append('      <text x="96" y="16" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="11">Curated Daily</text>')
    
    tracks = [
        ("Starboy", "The Weeknd ft. Daft Punk", "03:50", "#212130"),
        ("Yellow", "Coldplay - Parachutes", "04:29", "#1E202B"),
        ("Birds of a Feather", "Billie Eilish - Hit Me Hard", "03:14", "#1A222C"),
        ("Levitating", "Dua Lipa - Future Nostalgia", "03:23", "#2A1E2E")
    ]
    for i, (tname, tartist, tdur, bg_thumb) in enumerate(tracks):
        ty = 30 + i * 58
        s1.append(f'      <g transform="translate(0, {ty})">')
        s1.append(f'        <rect width="353" height="50" rx="12" fill="#12121A" stroke="#1D1D28" stroke-width="1"/>')
        s1.append(f'        <rect x="8" y="7" width="36" height="36" rx="8" fill="{bg_thumb}"/>')
        s1.append(f'        <polygon points="22,20 22,30 30,25" fill="#FFFFFF" fill-opacity="0.8"/>')
        s1.append(f'        <text x="54" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="600">{tname}</text>')
        s1.append(f'        <text x="54" y="38" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="10">{tartist}</text>')
        s1.append(f'        <text x="316" y="31" fill="#6A6A80" font-family="Inter, sans-serif" font-size="10">{tdur}</text>')
        s1.append(f'        <circle cx="340" cy="25" r="2" fill="#6A6A80"/><circle cx="340" cy="20" r="2" fill="#6A6A80"/><circle cx="340" cy="30" r="2" fill="#6A6A80"/>')
        s1.append('      </g>')
    s1.append('    </g>')

    # Floating Mini Player
    s1.append('    <!-- Floating Mini Player -->')
    s1.append('    <g transform="translate(16, 700)">')
    s1.append('      <rect width="361" height="58" rx="16" fill="#151522" stroke="#2A2A3C" stroke-width="1.2"/>')
    s1.append('      <rect x="8" y="8" width="42" height="42" rx="10" fill="url(#albumArtGrad)"/>')
    s1.append('      <text x="60" y="26" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="700">Blinding Lights</text>')
    s1.append('      <text x="60" y="42" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="10">The Weeknd - After Hours</text>')
    # Mini controls: Play & Next
    s1.append('      <circle cx="300" cy="29" r="16" fill="#3D5AFE"/>')
    s1.append('      <polygon points="297,23 297,35 306,29" fill="#FFFFFF"/>')
    s1.append('      <path d="M334,23 L334,35 M334,29 L326,23 L326,35 Z" fill="#8E8EA8"/>')
    # Progress mini line
    s1.append('      <rect x="0" y="56" width="361" height="2" rx="1" fill="#222232"/>')
    s1.append('      <rect x="0" y="56" width="180" height="2" rx="1" fill="#3D5AFE"/>')
    s1.append('    </g>')

    s1.append(draw_navbar(0))
    s1.append(close_phone())
    svg.append("\n".join(s1))

    # =========================================================================
    # SCREEN 2: NOW PLAYING - AUDIOPHILE PLAYER (EXCLUSIVE CODEC BADGE)
    # =========================================================================
    s2 = []
    s2.append(draw_phone_chassis(520, 140, "Screen 02", "Now Playing (Exclusive Codec Badge)"))

    # Top Bar
    s2.append('    <!-- Top Player Bar -->')
    s2.append('    <g transform="translate(20, 56)">')
    s2.append('      <path d="M6,10 L16,20 L26,10" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round"/>')
    s2.append('      <text x="176" y="16" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="11" font-weight="700" letter-spacing="1" text-anchor="middle">NOW PLAYING</text>')
    s2.append('      <g transform="translate(326, 2)">')
    s2.append('        <circle cx="12" cy="12" r="12" fill="#141420"/>')
    s2.append('        <path d="M7,12 A5,5 0 0,1 17,12 M5,12 A7,7 0 0,1 19,12" fill="none" stroke="#00E5FF" stroke-width="1.8"/>')
    s2.append('      </g>')
    s2.append('    </g>')

    # Album Vinyl Artwork
    s2.append('    <!-- Large Album Artwork -->')
    s2.append('    <g transform="translate(36, 106)">')
    s2.append('      <rect width="321" height="321" rx="28" fill="url(#albumArtGrad)" stroke="#3E1A22" stroke-width="2"/>')
    s2.append('      <circle cx="160" cy="160" r="70" fill="#000000" fill-opacity="0.4" stroke="#FFFFFF" stroke-opacity="0.1" stroke-width="8"/>')
    s2.append('      <circle cx="160" cy="160" r="24" fill="#B71C1C"/>')
    s2.append('      <circle cx="160" cy="160" r="6" fill="#FFFFFF"/>')
    # Subtle ambient lighting glow below artwork
    s2.append('      <ellipse cx="160" cy="335" rx="130" ry="12" fill="#B71C1C" fill-opacity="0.25"/>')
    s2.append('    </g>')

    # Track Metadata
    s2.append('    <!-- Track Title and Artist -->')
    s2.append('    <g transform="translate(36, 452)">')
    s2.append('      <text x="0" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="22" font-weight="800">Blinding Lights</text>')
    s2.append('      <text x="0" y="46" fill="#9E9EB6" font-family="Inter, sans-serif" font-size="14" font-weight="500">The Weeknd - After Hours</text>')
    # Heart favorite
    s2.append('      <path d="M305,25 C305,20 300,16 295,16 C290,16 287,19 285,22 C283,19 280,16 275,16 C270,16 265,20 265,25 C265,34 285,46 285,46 C285,46 305,34 305,25 Z" fill="#E53935"/>')
    s2.append('    </g>')

    # CRITICAL REQUIREMENT: EXCLUSIVE AUDIOPHILE CODEC BADGE (ONLY IN PLAYER!)
    s2.append('    <!-- EXCLUSIVE AUDIOPHILE CODEC BADGE (Player-Only Visibility) -->')
    s2.append('    <g transform="translate(36, 516)">')
    s2.append('      <rect width="321" height="34" rx="10" fill="#101826" stroke="#00E5FF" stroke-width="1.2"/>')
    s2.append('      <circle cx="18" cy="17" r="4" fill="#00E5FF"/>')
    s2.append('      <text x="30" y="21" fill="#00E5FF" font-family="Inter, sans-serif" font-size="10" font-weight="700" letter-spacing="0.8">HI-RES LOSSLESS</text>')
    s2.append('      <line x1="130" y1="9" x2="130" y2="25" stroke="#223348" stroke-width="1"/>')
    s2.append('      <text x="142" y="21" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="700" letter-spacing="0.5">FLAC 96kHz / 24-bit</text>')
    s2.append('      <rect x="250" y="7" width="60" height="20" rx="6" fill="#00E676" fill-opacity="0.15" stroke="#00E676" stroke-width="0.8"/>')
    s2.append('      <text x="280" y="21" fill="#00E676" font-family="Inter, sans-serif" font-size="9" font-weight="700" text-anchor="middle">BIT-PERFECT</text>')
    s2.append('    </g>')

    # Interactive Waveform & Scrubber
    s2.append('    <!-- Waveform Scrubber -->')
    s2.append('    <g transform="translate(36, 568)">')
    # Waveform vertical bars
    bar_heights = [6, 12, 18, 14, 22, 28, 16, 24, 30, 26, 18, 12, 22, 28, 32, 20, 16, 26, 30, 14, 18, 22, 16, 8, 14, 20, 28, 18, 10, 16, 22, 14]
    for b_idx, bh in enumerate(bar_heights):
        bx = b_idx * 10
        by = 20 - bh / 2
        bcolor = accent if bx < 160 else "#252538"
        s2.append(f'      <rect x="{bx}" y="{by}" width="4" height="{bh}" rx="2" fill="{bcolor}"/>')
    # Seek progress handle
    s2.append('      <circle cx="160" cy="20" r="7" fill="#FFFFFF" stroke="#3D5AFE" stroke-width="3"/>')
    s2.append('      <text x="0" y="44" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="10" font-weight="600">01:42</text>')
    s2.append('      <text x="321" y="44" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="10" font-weight="600" text-anchor="end">03:20</text>')
    s2.append('    </g>')

    # Master Playback Controls
    s2.append('    <!-- Playback Controls -->')
    s2.append('    <g transform="translate(36, 634)">')
    # Shuffle
    s2.append('      <path d="M12,25 L24,37 M12,37 L24,25" stroke="#3D5AFE" stroke-width="2" stroke-linecap="round"/>')
    # Previous
    s2.append('      <polygon points="90,31 106,20 106,42" fill="#FFFFFF"/>')
    s2.append('      <rect x="84" y="20" width="4" height="22" rx="1.5" fill="#FFFFFF"/>')
    # Main Play/Pause Button
    s2.append('      <circle cx="160" cy="31" r="34" fill="url(#accentGrad)" stroke="#7986CB" stroke-width="2"/>')
    s2.append('      <rect x="150" y="19" width="6" height="24" rx="2" fill="#FFFFFF"/>')
    s2.append('      <rect x="164" y="19" width="6" height="24" rx="2" fill="#FFFFFF"/>')
    # Next
    s2.append('      <polygon points="230,31 214,20 214,42" fill="#FFFFFF"/>')
    s2.append('      <rect x="232" y="20" width="4" height="22" rx="1.5" fill="#FFFFFF"/>')
    # Repeat
    s2.append('      <path d="M296,25 A8,8 0 1,1 292,36" fill="none" stroke="#8E8EA8" stroke-width="2"/>')
    s2.append('    </g>')

    # Bottom Quick DSP & Utility Toolbar
    s2.append('    <!-- Bottom Studio DSP Shortcuts -->')
    s2.append('    <g transform="translate(36, 722)">')
    s2.append('      <rect width="321" height="46" rx="16" fill="#12121D" stroke="#222232" stroke-width="1"/>')
    # Equalizer studio button (Highlighted)
    s2.append('      <g transform="translate(16, 8)">')
    s2.append('        <rect width="90" height="30" rx="8" fill="#3D5AFE" fill-opacity="0.2" stroke="#3D5AFE" stroke-width="1"/>')
    s2.append('        <text x="45" y="19" fill="#536DFE" font-family="Inter, sans-serif" font-size="10" font-weight="700" text-anchor="middle">EQ &amp; 8D DSP</text>')
    s2.append('      </g>')
    # Lyrics button
    s2.append('      <g transform="translate(122, 8)">')
    s2.append('        <rect width="80" height="30" rx="8" fill="#181826"/>')
    s2.append('        <text x="40" y="19" fill="#D0D0E2" font-family="Inter, sans-serif" font-size="10" font-weight="600" text-anchor="middle">LYRICS</text>')
    s2.append('      </g>')
    # Party Jamming button
    s2.append('      <g transform="translate(218, 8)">')
    s2.append('        <rect width="86" height="30" rx="8" fill="#181826"/>')
    s2.append('        <text x="43" y="19" fill="#00E5FF" font-family="Inter, sans-serif" font-size="10" font-weight="600" text-anchor="middle">JAM PARTY</text>')
    s2.append('      </g>')
    s2.append('    </g>')

    s2.append(close_phone())
    svg.append("\n".join(s2))

    # =========================================================================
    # SCREEN 3: EQUALIZER & 8D STUDIO DSP (0-100% ROTARY DIAL & NO DROP DROPOUTS)
    # =========================================================================
    s3 = []
    s3.append(draw_phone_chassis(980, 140, "Screen 03", "Equalizer & 8D Studio DSP"))

    # Top Header & Master Switch
    s3.append('    <!-- Studio Sheet Header -->')
    s3.append('    <g transform="translate(20, 56)">')
    s3.append('      <rect x="156" y="0" width="40" height="4" rx="2" fill="#333348"/>')
    s3.append('      <text x="0" y="30" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="17" font-weight="800">Equalizer &amp; Spatial DSP</text>')
    # Master Toggle (ON)
    s3.append('      <g transform="translate(295, 12)">')
    s3.append('        <rect width="50" height="26" rx="13" fill="#00E676"/>')
    s3.append('        <circle cx="37" cy="13" r="10" fill="#FFFFFF"/>')
    s3.append('      </g>')
    s3.append('    </g>')

    # Preset Chips Row
    s3.append('    <!-- Preset Chips -->')
    s3.append('    <g transform="translate(20, 104)">')
    presets = [("Flat", False), ("Audiophile Pure", True), ("Bass Punch", False), ("8D Orbital", False)]
    px_pos = 0
    for pname, p_active in presets:
        pw = len(pname) * 7.5 + 24
        pfill = accent if p_active else "#141420"
        pstroke = accent if p_active else "#242436"
        ptext = "#FFFFFF" if p_active else "#8E8EA8"
        s3.append(f'      <g transform="translate({px_pos}, 0)">')
        s3.append(f'        <rect width="{pw}" height="30" rx="15" fill="{pfill}" stroke="{pstroke}" stroke-width="1"/>')
        s3.append(f'        <text x="{pw/2}" y="19" fill="{ptext}" font-family="Inter, sans-serif" font-size="10" font-weight="600" text-anchor="middle">{pname}</text>')
        s3.append('      </g>')
        px_pos += pw + 8
    s3.append('    </g>')

    # Central Master 8D Rotary Knob (270-deg studio arc, strict 0% min to 100% max clamping!)
    s3.append('    <!-- 270-Degree Master 8D Studio Rotary Dial -->')
    s3.append('    <g transform="translate(20, 154)">')
    s3.append('      <rect width="353" height="226" rx="20" fill="#11111A" stroke="#222234" stroke-width="1.2"/>')
    s3.append('      <text x="176" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="13" font-weight="700" text-anchor="middle">8D SPATIAL ORBITAL BINAURAL ENGINE</text>')
    s3.append('      <text x="176" y="38" fill="#00E5FF" font-family="Inter, sans-serif" font-size="9" font-weight="600" text-anchor="middle">BINAURAL AUDIO - ZERO DROPOUTS - NO PITCH RESAMPLING</text>')

    # Big Rotary Dial graphics (Center at 176, 120)
    # Background Track arc (270 degrees: from 135 deg to 45 deg)
    s3.append('      <g transform="translate(176, 120)">')
    s3.append('        <!-- Outer Dial Base Ring -->')
    s3.append('        <circle cx="0" cy="0" r="62" fill="#0D0D14" stroke="#1D1D2C" stroke-width="8"/>')
    # Active filled arc up to 75%
    s3.append('        <!-- 75% Active Arc in Cyan / Accent -->')
    s3.append('        <path d="M-43.8,43.8 A62,62 0 1,1 62,0" fill="none" stroke="url(#accentGrad)" stroke-width="8" stroke-linecap="round"/>')
    # Center Knob Cap
    s3.append('        <circle cx="0" cy="0" r="48" fill="#181824" stroke="#2D2D42" stroke-width="2"/>')
    # Pointer marker on knob
    s3.append('        <line x1="0" y1="-32" x2="0" y2="-44" stroke="#FFFFFF" stroke-width="3.5" stroke-linecap="round"/>')
    # Readout inside knob
    s3.append('        <text x="0" y="6" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="20" font-weight="800" text-anchor="middle">75%</text>')
    s3.append('        <text x="0" y="20" fill="#3D5AFE" font-family="Inter, sans-serif" font-size="8" font-weight="700" text-anchor="middle">ORBIT INTENSITY</text>')
    # Bottom labels: 0% MIN and 100% MAX (Strict clamp)
    s3.append('        <text x="-48" y="62" fill="#6A6A85" font-family="Inter, sans-serif" font-size="9" font-weight="700" text-anchor="middle">0% MIN</text>')
    s3.append('        <text x="48" y="62" fill="#6A6A85" font-family="Inter, sans-serif" font-size="9" font-weight="700" text-anchor="middle">100% MAX</text>')
    s3.append('      </g>')
    # Orbital speed chips
    s3.append('      <g transform="translate(36, 196)">')
    speeds = ["Slow Orbit", "Medium Orbit", "Hyper 16D Helix"]
    for s_idx, sp in enumerate(speeds):
        sx = s_idx * 96
        sfill = "#1E1E30" if s_idx == 1 else "#141420"
        stext = "#00E5FF" if s_idx == 1 else "#72728A"
        s3.append(f'        <rect x="{sx}" y="0" width="90" height="20" rx="10" fill="{sfill}"/>')
        s3.append(f'        <text x="{sx + 45}" y="14" fill="{stext}" font-family="Inter, sans-serif" font-size="8" font-weight="600" text-anchor="middle">{sp}</text>')
    s3.append('      </g>')
    s3.append('    </g>')

    # Dual Rotary Knobs: Hardware Low-Shelf Bass Boost & Virtualizer Presence
    s3.append('    <!-- Bass Boost & Virtualizer Studio Knobs -->')
    s3.append('    <g transform="translate(20, 394)">')
    # Bass Boost Left Card
    s3.append('      <g transform="translate(0, 0)">')
    s3.append('        <rect width="170" height="136" rx="18" fill="#11111A" stroke="#222234" stroke-width="1.2"/>')
    s3.append('        <text x="85" y="22" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="700" text-anchor="middle">BASS BOOST</text>')
    s3.append('        <text x="85" y="34" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="8" text-anchor="middle">Hardware &lt;250Hz Filter</text>')
    # Mini rotary knob
    s3.append('        <circle cx="85" cy="74" r="30" fill="#0E0E16" stroke="#26263A" stroke-width="5"/>')
    s3.append('        <path d="M64,95 A30,30 0 1,1 115,74" fill="none" stroke="#FF1744" stroke-width="5" stroke-linecap="round"/>')
    s3.append('        <circle cx="85" cy="74" r="22" fill="#161622"/>')
    s3.append('        <text x="85" y="78" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="800" text-anchor="middle">80%</text>')
    s3.append('        <text x="40" y="122" fill="#6A6A82" font-family="Inter, sans-serif" font-size="8" font-weight="600">0%</text>')
    s3.append('        <text x="130" y="122" fill="#6A6A82" font-family="Inter, sans-serif" font-size="8" font-weight="600">100%</text>')
    s3.append('      </g>')

    # Virtualizer Right Card
    s3.append('      <g transform="translate(183, 0)">')
    s3.append('        <rect width="170" height="136" rx="18" fill="#11111A" stroke="#222234" stroke-width="1.2"/>')
    s3.append('        <text x="85" y="22" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="700" text-anchor="middle">VIRTUALIZER</text>')
    s3.append('        <text x="85" y="34" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="8" text-anchor="middle">2.5kHz-16kHz Spatial Presence</text>')
    # Mini rotary knob
    s3.append('        <circle cx="85" cy="74" r="30" fill="#0E0E16" stroke="#26263A" stroke-width="5"/>')
    s3.append('        <path d="M64,95 A30,30 0 1,1 106,53" fill="none" stroke="#00E676" stroke-width="5" stroke-linecap="round"/>')
    s3.append('        <circle cx="85" cy="74" r="22" fill="#161622"/>')
    s3.append('        <text x="85" y="78" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="800" text-anchor="middle">65%</text>')
    s3.append('        <text x="40" y="122" fill="#6A6A82" font-family="Inter, sans-serif" font-size="8" font-weight="600">0%</text>')
    s3.append('        <text x="130" y="122" fill="#6A6A82" font-family="Inter, sans-serif" font-size="8" font-weight="600">100%</text>')
    s3.append('      </g>')
    s3.append('    </g>')

    # 5-Band Graphic Equalizer Faders
    s3.append('    <!-- 5-Band Graphic Equalizer Sliders -->')
    s3.append('    <g transform="translate(20, 544)">')
    s3.append('      <rect width="353" height="206" rx="20" fill="#11111A" stroke="#222234" stroke-width="1.2"/>')
    s3.append('      <text x="16" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="700">5-BAND GRAPHIC EQUALIZER</text>')
    s3.append('      <text x="337" y="24" fill="#00E676" font-family="Inter, sans-serif" font-size="9" font-weight="600" text-anchor="end">±12 dB PRECISION</text>')
    
    bands = [("60Hz", "+4dB", 60), ("230Hz", "+2dB", 75), ("910Hz", "0dB", 90), ("3.6kHz", "+3dB", 68), ("14kHz", "+5dB", 55)]
    for i, (b_freq, b_val, h_pos) in enumerate(bands):
        bx = 25 + i * 65
        s3.append(f'      <g transform="translate({bx}, 42)">')
        # Center track zero line
        s3.append(f'        <line x1="16" y1="10" x2="16" y2="130" stroke="#202030" stroke-width="4" stroke-linecap="round"/>')
        s3.append(f'        <line x1="8" y1="70" x2="24" y2="70" stroke="#333348" stroke-width="1.5"/>')
        # Active color track
        s3.append(f'        <line x1="16" y1="{h_pos}" x2="16" y2="70" stroke="#3D5AFE" stroke-width="4"/>')
        # Fader Thumb knob
        s3.append(f'        <rect x="2" y="{h_pos - 8}" width="28" height="16" rx="6" fill="#1E1E2E" stroke="#536DFE" stroke-width="1.5"/>')
        s3.append(f'        <line x1="8" y1="{h_pos}" x2="24" y2="{h_pos}" stroke="#FFFFFF" stroke-width="1.5"/>')
        # dB and Frequency labels
        s3.append(f'        <text x="16" y="{h_pos - 12}" fill="#00E5FF" font-family="Inter, sans-serif" font-size="8" font-weight="700" text-anchor="middle">{b_val}</text>')
        s3.append(f'        <text x="16" y="148" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="9" font-weight="600" text-anchor="middle">{b_freq}</text>')
        s3.append('      </g>')
    s3.append('    </g>')

    s3.append(draw_navbar(4))
    s3.append(close_phone())
    svg.append("\n".join(s3))

    # =========================================================================
    # SCREEN 4: SEARCH & DEEP LEARNING HUM-TO-SONG RETRIEVAL PIPELINE
    # =========================================================================
    s4 = []
    s4.append(draw_phone_chassis(1440, 140, "Screen 04", "Hum-to-Song Deep Retrieval"))

    # Search Bar with Active Mic & Humming Mode
    s4.append('    <!-- Search Bar with Humming Activation -->')
    s4.append('    <g transform="translate(20, 56)">')
    s4.append('      <rect width="353" height="46" rx="14" fill="#13131D" stroke="#3D5AFE" stroke-width="1.5"/>')
    s4.append('      <path d="M16,23 L22,23 M19,16 L19,25" stroke="#8E8EA8" stroke-width="2"/>')
    s4.append('      <text x="32" y="28" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="500">Humming: "Da-na-na-na-na..."</text>')
    # Pulsing Mic Icon
    s4.append('      <g transform="translate(315, 8)">')
    s4.append('        <circle cx="15" cy="15" r="14" fill="#FF1744" fill-opacity="0.2"/>')
    s4.append('        <circle cx="15" cy="15" r="10" fill="#FF1744"/>')
    s4.append('        <rect x="13" y="10" width="4" height="7" rx="2" fill="#FFFFFF"/>')
    s4.append('        <path d="M10,13 A5,5 0 0,0 20,13 M15,18 L15,20" stroke="#FFFFFF" stroke-width="1.2" fill="none"/>')
    s4.append('      </g>')
    s4.append('    </g>')

    # Real-Time Deep Learning Melody Retrieval Architecture Card
    s4.append('    <!-- Real-Time Deep Learning Melody Retrieval Card -->')
    s4.append('    <g transform="translate(20, 116)">')
    s4.append('      <rect width="353" height="420" rx="20" fill="#101018" stroke="#25253A" stroke-width="1.2"/>')
    s4.append('      <rect x="16" y="16" width="186" height="20" rx="10" fill="#3D5AFE" fill-opacity="0.2" stroke="#3D5AFE" stroke-width="0.8"/>')
    s4.append('      <circle cx="26" cy="26" r="3.5" fill="#00E5FF"/>')
    s4.append('      <text x="36" y="30" fill="#00E5FF" font-family="Inter, sans-serif" font-size="8" font-weight="700" letter-spacing="0.5">NEURAL RETRIEVAL PIPELINE</text>')
    s4.append('      <text x="16" y="58" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="14" font-weight="700">Real-Time Hum Recognition</text>')
    s4.append('      <text x="16" y="74" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="10">Spectrogram Analysis -> Embedding -> Vector Search</text>')

    # Stage 1: Windowed STFT Log-Mel Spectrogram Visualizer
    s4.append('      <!-- Windowed STFT Spectrogram Visualizer -->')
    s4.append('      <g transform="translate(16, 88)">')
    s4.append('        <rect width="321" height="84" rx="12" fill="#08080E" stroke="#1D1D2C" stroke-width="1"/>')
    # Spectrogram heat grid matrix (frequency bins over time)
    for col in range(16):
        cx = 10 + col * 19
        for row in range(5):
            cy = 10 + row * 13
            # Fake heatmap color based on pitch pattern
            op = (abs(col - 8) + row) % 4
            colors = ["#00E5FF", "#3D5AFE", "#FF1744", "#FFD600"]
            s4.append(f'        <rect x="{cx}" y="{cy}" width="16" height="10" rx="2" fill="{colors[op]}" fill-opacity="0.75"/>')
    s4.append('        <text x="12" y="76" fill="#00E5FF" font-family="Inter, sans-serif" font-size="8" font-weight="700">WINDOWED STFT LOG-MEL SPECTROGRAM (80 BINS)</text>')
    s4.append('        <text x="310" y="76" fill="#00E676" font-family="Inter, sans-serif" font-size="8" font-weight="700" text-anchor="end">LIVE CAPTURE</text>')
    s4.append('      </g>')

    # Stage 2: Deep Melody Convolutional-Residual Encoder
    s4.append('      <!-- Deep Melody Encoder Layer -->')
    s4.append('      <g transform="translate(16, 184)">')
    s4.append('        <rect width="321" height="42" rx="10" fill="#141422" stroke="#25253A" stroke-width="1"/>')
    s4.append('        <circle cx="20" cy="21" r="5" fill="#7C4DFF"/>')
    s4.append('        <text x="34" y="19" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="700">Deep ResNet Melody Encoder</text>')
    s4.append('        <text x="34" y="32" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="8">Timbre &amp; noise-invariant melody abstraction</text>')
    s4.append('        <text x="306" y="26" fill="#00E676" font-family="Inter, sans-serif" font-size="9" font-weight="700" text-anchor="end">ACTIVE</text>')
    s4.append('      </g>')

    # Stage 3: 128-D Unit Melody Embedding & Vector Similarity Search
    s4.append('      <!-- 128-D Melody Embedding Vector -->')
    s4.append('      <g transform="translate(16, 236)">')
    s4.append('        <rect width="321" height="52" rx="10" fill="#141422" stroke="#25253A" stroke-width="1"/>')
    s4.append('        <text x="12" y="18" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="700">128-d Melody Embedding Fingerprint</text>')
    s4.append('        <!-- Vector bar blocks -->')
    for vi in range(24):
        vx = 12 + vi * 12.5
        vh = 8 + (vi * 7) % 14
        vcol = "#3D5AFE" if vi % 2 == 0 else "#00E5FF"
        s4.append(f'        <rect x="{vx}" y="26" width="9" height="{vh}" rx="2" fill="{vcol}"/>')
    s4.append('      </g>')

    # Stage 4: Cosine Vector Similarity Search against Database
    s4.append('      <!-- Vector Similarity Search -->')
    s4.append('      <g transform="translate(16, 298)">')
    s4.append('        <rect width="321" height="42" rx="10" fill="#141422" stroke="#25253A" stroke-width="1"/>')
    s4.append('        <text x="12" y="19" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="700">Vector Approximate Nearest Neighbors (ANN)</text>')
    s4.append('        <text x="12" y="32" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="8">Cosine Dot-Product Match over 4.8M Song Embeddings</text>')
    s4.append('        <text x="306" y="26" fill="#00E5FF" font-family="Inter, sans-serif" font-size="9" font-weight="700" text-anchor="end">&lt;14ms</text>')
    s4.append('      </g>')

    # Match Confidence Score Card
    s4.append('      <g transform="translate(16, 350)">')
    s4.append('        <rect width="321" height="54" rx="12" fill="#0D1E16" stroke="#00E676" stroke-width="1.2"/>')
    s4.append('        <circle cx="24" cy="27" r="8" fill="#00E676"/>')
    s4.append('        <path d="M20,27 L23,30 L28,24" fill="none" stroke="#000000" stroke-width="2"/>')
    s4.append('        <text x="40" y="24" fill="#00E676" font-family="Inter, sans-serif" font-size="11" font-weight="800">98.4% HIGH-CONFIDENCE MATCH</text>')
    s4.append('        <text x="40" y="40" fill="#8CE8B2" font-family="Inter, sans-serif" font-size="9">Calibrated Triplet-Loss Rank #1 Candidate</text>')
    s4.append('      </g>')
    s4.append('    </g>')

    # Identified Track Match Result
    s4.append('    <!-- Identified Track Card -->')
    s4.append('    <g transform="translate(20, 550)">')
    s4.append('      <text x="0" y="16" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="13" font-weight="700">Identified Song</text>')
    s4.append('      <g transform="translate(0, 26)">')
    s4.append('        <rect width="353" height="82" rx="16" fill="#13131F" stroke="#3D5AFE" stroke-width="1.5"/>')
    s4.append('        <rect x="12" y="12" width="58" height="58" rx="10" fill="url(#albumArtGrad)"/>')
    s4.append('        <text x="80" y="32" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="14" font-weight="700">Starboy</text>')
    s4.append('        <text x="80" y="48" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="11">The Weeknd ft. Daft Punk</text>')
    s4.append('        <text x="80" y="62" fill="#55556E" font-family="Inter, sans-serif" font-size="9">Starboy (Deluxe Edition) - 2016</text>')
    # Play Identified Song Button
    s4.append('        <g transform="translate(265, 23)">')
    s4.append('          <rect width="76" height="36" rx="12" fill="#3D5AFE"/>')
    s4.append('          <text x="38" y="22" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="700" text-anchor="middle">Play Now</text>')
    s4.append('        </g>')
    s4.append('      </g>')
    s4.append('    </g>')

    s4.append(draw_navbar(1))
    s4.append(close_phone())
    svg.append("\n".join(s4))

    # =========================================================================
    # SCREEN 5: LIBRARY & WEBDAV PERSONAL CLOUD STORAGE (CLEAN LAYOUT)
    # =========================================================================
    s5 = []
    s5.append(draw_phone_chassis(1900, 140, "Screen 05", "Library & WebDAV Personal Cloud"))

    # Library Header
    s5.append('    <!-- Library Header -->')
    s5.append('    <g transform="translate(20, 56)">')
    s5.append('      <text x="0" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="18" font-weight="800">My Library &amp; Cloud</text>')
    s5.append('      <g transform="translate(325, 4)">')
    s5.append('        <circle cx="12" cy="12" r="14" fill="#141420"/>')
    s5.append('        <path d="M12,7 L12,17 M7,12 L17,12" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round"/>')
    s5.append('      </g>')
    s5.append('    </g>')

    # WebDAV Personal Cloud Card (CLEAN CONSTRAINED LAYOUT - NO OVERFLOW!)
    s5.append('    <!-- WebDAV Personal Cloud Storage (Properly Constrained Inside Card) -->')
    s5.append('    <g transform="translate(20, 100)">')
    s5.append('      <rect width="353" height="150" rx="20" fill="#11111A" stroke="#25253A" stroke-width="1.2"/>')
    
    # Top Row: Icon + Title + Status Pill completely inside borders!
    s5.append('      <g transform="translate(16, 16)">')
    s5.append('        <rect width="36" height="36" rx="10" fill="#3D5AFE" fill-opacity="0.15" stroke="#3D5AFE" stroke-width="1"/>')
    s5.append('        <path d="M10,23 C9,23 7,21 7,19 C7,17 9,15 11,15 C12,12 15,10 18,10 C22,10 25,13 25,16 C27,16 29,18 29,20 C29,22 27,23 25,23 Z" fill="none" stroke="#3D5AFE" stroke-width="1.5"/>')
    s5.append('        <!-- Title (Truncated, inside box) -->')
    s5.append('        <text x="44" y="16" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="700">WebDAV Cloud Storage</text>')
    s5.append('        <text x="44" y="30" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="9">Personal Self-Hosted Music NAS</text>')
    # Status Badge: DISCONNECTED (Strictly inside right side of the card!)
    s5.append('        <g transform="translate(225, 6)">')
    s5.append('          <rect width="90" height="24" rx="8" fill="#24141A" stroke="#FF5252" stroke-width="1"/>')
    s5.append('          <circle cx="12" cy="12" r="3" fill="#FF5252"/>')
    s5.append('          <text x="20" y="16" fill="#FF5252" font-family="Inter, sans-serif" font-size="8" font-weight="700">DISCONNECTED</text>')
    s5.append('        </g>')
    s5.append('      </g>')

    # Storage Stats and Endpoint
    s5.append('      <g transform="translate(16, 68)">')
    s5.append('        <text x="0" y="14" fill="#6A6A80" font-family="Inter, sans-serif" font-size="9">HOST ENDPOINT: https://nas.personal-cloud.local:8443/music</text>')
    # Progress Bar
    s5.append('        <rect x="0" y="24" width="321" height="6" rx="3" fill="#1C1C2C"/>')
    s5.append('        <rect x="0" y="24" width="110" height="6" rx="3" fill="#3D5AFE"/>')
    s5.append('        <text x="0" y="46" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="600">128.4 GB Cached</text>')
    s5.append('        <text x="321" y="46" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="10" text-anchor="end">500 GB Total</text>')
    s5.append('      </g>')
    # Connect / Sync button inside card
    s5.append('      <g transform="translate(16, 126)">')
    s5.append('        <text x="0" y="12" fill="#3D5AFE" font-family="Inter, sans-serif" font-size="10" font-weight="700">Tap to reconnect server</text>')
    s5.append('      </g>')
    s5.append('    </g>')

    # Offline Playback & Downloads Section
    s5.append('    <!-- Offline Playback Section -->')
    s5.append('    <g transform="translate(20, 266)">')
    s5.append('      <rect width="353" height="74" rx="16" fill="#11111A" stroke="#25253A" stroke-width="1.2"/>')
    s5.append('      <circle cx="32" cy="37" r="16" fill="#00E676" fill-opacity="0.15"/>')
    s5.append('      <path d="M26,37 L30,41 L38,33" fill="none" stroke="#00E676" stroke-width="2"/>')
    s5.append('      <text x="60" y="32" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="13" font-weight="700">Offline Playback Ready</text>')
    s5.append('      <text x="60" y="48" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="10">428 high-res lossless songs downloaded</text>')
    s5.append('      <rect x="275" y="24" width="62" height="26" rx="8" fill="#181828"/>')
    s5.append('      <text x="306" y="41" fill="#00E676" font-family="Inter, sans-serif" font-size="9" font-weight="700" text-anchor="middle">ACTIVE</text>')
    s5.append('    </g>')

    # Compact Streamlined Radios & Playlists (Replacing bloated cards!)
    s5.append('    <!-- Compact Filter Chips: Radios & Playlists -->')
    s5.append('    <g transform="translate(20, 356)">')
    s5.append('      <text x="0" y="16" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="13" font-weight="700">Quick Filters</text>')
    chips = ["All Songs", "Downloaded", "Audiophile Master", "Synthwave Radio", "Live Sets"]
    cx_pos = 0
    for c_i, c_name in enumerate(chips):
        cw = len(c_name) * 6.5 + 20
        c_bg = "#3D5AFE" if c_i == 0 else "#141420"
        c_fg = "#FFFFFF" if c_i == 0 else "#8E8EA8"
        s5.append(f'      <g transform="translate({cx_pos}, 28)">')
        s5.append(f'        <rect width="{cw}" height="28" rx="14" fill="{c_bg}"/>')
        s5.append(f'        <text x="{cw/2}" y="18" fill="{c_fg}" font-family="Inter, sans-serif" font-size="9" font-weight="600" text-anchor="middle">{c_name}</text>')
        s5.append('      </g>')
        cx_pos += cw + 6
    s5.append('    </g>')

    # Library Song List (Clean, NO codec badges in library items!)
    s5.append('    <!-- Library Tracks (Strictly NO Codec Badges) -->')
    s5.append('    <g transform="translate(20, 424)">')
    lib_tracks = [
        ("Midnight City", "M83 - Hurry Up, We're Dreaming", "04:03"),
        ("After Hours", "The Weeknd - After Hours", "06:01"),
        ("Viva La Vida", "Coldplay - Death and All His Friends", "04:01"),
        ("Ocean Eyes", "Billie Eilish - Don't Smile At Me", "03:20"),
        ("Don't Start Now", "Dua Lipa - Future Nostalgia", "03:03")
    ]
    for i, (lname, lartist, ldur) in enumerate(lib_tracks):
        ly = i * 58
        s5.append(f'      <g transform="translate(0, {ly})">')
        s5.append(f'        <rect width="353" height="50" rx="12" fill="#111118" stroke="#1C1C28" stroke-width="1"/>')
        s5.append(f'        <rect x="8" y="7" width="36" height="36" rx="8" fill="#1C1C2A"/>')
        s5.append(f'        <text x="26" y="28" fill="#55556E" font-family="Inter, sans-serif" font-size="10" font-weight="700" text-anchor="middle">{i+1}</text>')
        s5.append(f'        <text x="52" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="12" font-weight="600">{lname}</text>')
        s5.append(f'        <text x="52" y="38" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="10">{lartist}</text>')
        s5.append(f'        <text x="320" y="31" fill="#6A6A80" font-family="Inter, sans-serif" font-size="10">{ldur}</text>')
        s5.append('      </g>')
    s5.append('    </g>')

    s5.append(draw_navbar(3))
    s5.append(close_phone())
    svg.append("\n".join(s5))

    # =========================================================================
    # SCREEN 6: LIVE CONCERT ARENA & STADIUM PASS BOOKING
    # =========================================================================
    s6 = []
    s6.append(draw_phone_chassis(2360, 140, "Screen 06", "Concert Arena & Stadium Booking"))

    # Concert Arena Header
    s6.append('    <!-- Concert Arena Header -->')
    s6.append('    <g transform="translate(20, 56)">')
    s6.append('      <text x="0" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="18" font-weight="800">Live Concert Arena</text>')
    s6.append('      <rect x="250" y="6" width="103" height="24" rx="12" fill="#24123E" stroke="#7C4DFF" stroke-width="1"/>')
    s6.append('      <circle cx="262" cy="18" r="4" fill="#00E5FF"/>')
    s6.append('      <text x="272" y="22" fill="#00E5FF" font-family="Inter, sans-serif" font-size="9" font-weight="700">GLOBAL STAGE</text>')
    s6.append('    </g>')

    # Dual Mode Segmented Switcher (Virtual Live Stage vs Physical Stadium Booking)
    s6.append('    <!-- Dual Mode Switcher -->')
    s6.append('    <g transform="translate(20, 100)">')
    s6.append('      <rect width="353" height="42" rx="14" fill="#13131F" stroke="#25253A" stroke-width="1"/>')
    # Virtual Live Stage (Tab 1)
    s6.append('      <g transform="translate(4, 4)">')
    s6.append('        <rect width="170" height="34" rx="10" fill="#3D5AFE"/>')
    s6.append('        <text x="85" y="22" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="700" text-anchor="middle">Online Virtual Stage</text>')
    s6.append('      </g>')
    # Physical Stadium Tour (Tab 2)
    s6.append('      <g transform="translate(178, 4)">')
    s6.append('        <rect width="170" height="34" rx="10" fill="transparent"/>')
    s6.append('        <text x="85" y="22" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="11" font-weight="600" text-anchor="middle">Physical Stadium Pass</text>')
    s6.append('      </g>')
    s6.append('    </g>')

    # Live Virtual Dome Stage Card
    s6.append('    <!-- Virtual Live Stage Card -->')
    s6.append('    <g transform="translate(20, 154)">')
    s6.append('      <rect width="353" height="186" rx="20" fill="url(#concertHeroGrad)" stroke="#53348A" stroke-width="1.5"/>')
    # Live Broadcast Tag
    s6.append('      <rect x="16" y="16" width="94" height="22" rx="8" fill="#E53935"/>')
    s6.append('      <circle cx="28" cy="27" r="4" fill="#FFFFFF"/>')
    s6.append('      <text x="38" y="31" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="9" font-weight="800">STREAMING</text>')
    s6.append('      <text x="120" y="31" fill="#00E5FF" font-family="Inter, sans-serif" font-size="9" font-weight="700">4K 60FPS + 3D BINAURAL AUDIO</text>')
    
    s6.append('      <text x="16" y="68" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="17" font-weight="800">Coldplay: Music of the Spheres</text>')
    s6.append('      <text x="16" y="86" fill="#D0C8E8" font-family="Inter, sans-serif" font-size="11">Global Virtual Live Dome - Tokyo &amp; London Sync</text>')

    # Multi-Cam Angle Switcher Preview
    s6.append('      <g transform="translate(16, 102)">')
    cams = [("Main Stage", True), ("Front Row 360", False), ("Drummer Cam", False), ("Drone Cam", False)]
    for ci, (cname, c_act) in enumerate(cams):
        cx = ci * 78
        cbg = "#3D5AFE" if c_act else "#18102C"
        cst = "#536DFE" if c_act else "#342252"
        cfg = "#FFFFFF" if c_act else "#A094C0"
        s6.append(f'        <rect x="{cx}" y="0" width="72" height="26" rx="8" fill="{cbg}" stroke="{cst}" stroke-width="1"/>')
        s6.append(f'        <text x="{cx + 36}" y="16" fill="{cfg}" font-family="Inter, sans-serif" font-size="8" font-weight="700" text-anchor="middle">{cname}</text>')
    s6.append('      </g>')

    # Virtual Audience Stats
    s6.append('      <g transform="translate(16, 144)">')
    s6.append('        <circle cx="8" cy="14" r="4" fill="#00E676"/>')
    s6.append('        <text x="18" y="18" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="600">42,190 Fans in Virtual Dome</text>')
    s6.append('        <rect x="210" y="2" width="111" height="26" rx="8" fill="#3D5AFE"/>')
    s6.append('        <text x="265" y="18" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="9" font-weight="700" text-anchor="middle">Join Virtual Pit</text>')
    s6.append('      </g>')
    s6.append('    </g>')

    # Physical Stadium Tour Ticket Pass Management (True Authentic Data!)
    s6.append('    <!-- Stadium Ticket Management (Authentic Tour Data) -->')
    s6.append('    <g transform="translate(20, 354)">')
    s6.append('      <text x="0" y="16" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="14" font-weight="700">Physical Stadium Tour Passes</text>')
    s6.append('      <text x="353" y="16" fill="#3D5AFE" font-family="Inter, sans-serif" font-size="10" font-weight="600" text-anchor="end">Tour Schedule</text>')

    # Digital NFC / QR Stadium Pass Card
    s6.append('      <g transform="translate(0, 28)">')
    s6.append('        <rect width="353" height="220" rx="20" fill="url(#ticketFoilGrad)" stroke="#4A3478" stroke-width="1.5"/>')
    # Holographic pass header
    s6.append('        <rect x="16" y="16" width="130" height="20" rx="8" fill="#3D5AFE" fill-opacity="0.3" stroke="#3D5AFE" stroke-width="1"/>')
    s6.append('        <text x="81" y="30" fill="#00E5FF" font-family="Inter, sans-serif" font-size="8" font-weight="800" text-anchor="middle">OFFICIAL STADIUM PASS</text>')
    s6.append('        <text x="337" y="30" fill="#00E676" font-family="Inter, sans-serif" font-size="10" font-weight="700" text-anchor="end">NFC VERIFIED</text>')
    
    s6.append('        <text x="16" y="62" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="16" font-weight="800">The Weeknd: After Hours Tour</text>')
    s6.append('        <text x="16" y="78" fill="#B0A4D0" font-family="Inter, sans-serif" font-size="11">Wembley Stadium, London - Gate 4B Turnstile 12</text>')
    s6.append('        <text x="16" y="94" fill="#8878A8" font-family="Inter, sans-serif" font-size="9">Saturday, Nov 14, 2026 - Doors Open 17:30 BST</text>')

    # Ticket Tier & Seat Allocation Matrix
    s6.append('        <g transform="translate(16, 108)">')
    s6.append('          <rect width="321" height="54" rx="12" fill="#0D091A" stroke="#2D1F48" stroke-width="1"/>')
    # Tier: VIP Golden Circle
    s6.append('          <text x="16" y="20" fill="#7C4DFF" font-family="Inter, sans-serif" font-size="9" font-weight="700">TIER</text>')
    s6.append('          <text x="16" y="38" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="800">VIP Golden Circle</text>')
    # Section
    s6.append('          <text x="120" y="20" fill="#7C4DFF" font-family="Inter, sans-serif" font-size="9" font-weight="700">SECTION</text>')
    s6.append('          <text x="120" y="38" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="800">SEC A2</text>')
    # Row & Seat
    s6.append('          <text x="200" y="20" fill="#7C4DFF" font-family="Inter, sans-serif" font-size="9" font-weight="700">ROW / SEAT</text>')
    s6.append('          <text x="200" y="38" fill="#00E676" font-family="Inter, sans-serif" font-size="11" font-weight="800">ROW 4, SEAT 18</text>')
    s6.append('        </g>')

    # NFC / QR Contactless Entry Simulation
    s6.append('        <g transform="translate(16, 172)">')
    s6.append('          <rect width="180" height="34" rx="10" fill="#3D5AFE"/>')
    s6.append('          <text x="90" y="22" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="700" text-anchor="middle">Add to Apple / Google Wallet</text>')
    s6.append('          <rect x="206" y="0" width="131" height="34" rx="10" fill="#1C1434" stroke="#483670" stroke-width="1"/>')
    s6.append('          <text x="271" y="22" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="10" font-weight="600" text-anchor="middle">View Dynamic QR</text>')
    s6.append('        </g>')
    s6.append('      </g>')
    s6.append('    </g>')

    # Additional upcoming physical concert dates
    s6.append('    <!-- Upcoming Physical Tour Dates -->')
    s6.append('    <g transform="translate(20, 616)">')
    s6.append('      <rect width="353" height="52" rx="14" fill="#12121D" stroke="#25253A" stroke-width="1"/>')
    s6.append('      <text x="16" y="24" fill="#FFFFFF" font-family="Inter, sans-serif" font-size="11" font-weight="700">Billie Eilish: Hit Me Hard Arena Tour</text>')
    s6.append('      <text x="16" y="38" fill="#8E8EA8" font-family="Inter, sans-serif" font-size="9">O2 Arena, London - Dec 02, 2026</text>')
    s6.append('      <rect x="265" y="12" width="76" height="28" rx="8" fill="#1E1E30" stroke="#3D5AFE" stroke-width="1"/>')
    s6.append('      <text x="303" y="29" fill="#00E5FF" font-family="Inter, sans-serif" font-size="9" font-weight="700" text-anchor="middle">Get Tickets</text>')
    s6.append('    </g>')

    s6.append(draw_navbar(2))
    s6.append(close_phone())
    svg.append("\n".join(s6))

    # Close SVG
    svg.append('</svg>')
    
    return "\n".join(svg)

if __name__ == "__main__":
    content = generate_svg()
    with open("open_aamps_figma_screens.svg", "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Generated open_aamps_figma_screens.svg ({len(content)} bytes)")
