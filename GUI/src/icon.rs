// Icon data: 32x32 RGBA pixel data (simple blue "C" shape on dark background)
// This is a pre-rendered icon embedded in the binary
pub fn icon_data() -> Vec<u8> {
    // 32x32 image, RGBA format
    let mut pixels = vec![0u8; 32 * 32 * 4];
    
    for y in 0..32 {
        for x in 0..32 {
            let idx = (y * 32 + x) * 4;
            // Default: dark background
            pixels[idx] = 22;     // R
            pixels[idx + 1] = 27; // G
            pixels[idx + 2] = 34; // B
            pixels[idx + 3] = 255; // A
            
            // Draw "C" shape (bracket)
            if x >= 4 && x <= 14 && y >= 6 && y <= 26 {
                if x == 4 || (y == 6 && x <= 12) || (y == 26 && x <= 12) {
                    pixels[idx] = 88;     // R
                    pixels[idx + 1] = 166; // G
                    pixels[idx + 2] = 255; // B
                    pixels[idx + 3] = 255; // A
                }
            }
            
            // Draw code lines (right side)
            if x >= 18 && x <= 28 {
                if (y == 10 && x <= 26) || (y == 15 && x <= 24) || (y == 20 && x <= 26) {
                    pixels[idx] = 88;     // R
                    pixels[idx + 1] = 166; // G
                    pixels[idx + 2] = 255; // B
                    pixels[idx + 3] = 200; // A
                }
            }
            
            // Small dot accent
            if x >= 20 && x <= 22 && y >= 24 && y <= 26 {
                pixels[idx] = 88;     // R
                pixels[idx + 1] = 166; // G
                pixels[idx + 2] = 255; // B
                pixels[idx + 3] = 150; // A
            }
        }
    }
    
    pixels
}

pub fn icon_width() -> u32 { 32 }
pub fn icon_height() -> u32 { 32 }
