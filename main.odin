package hellope

import "core:fmt"
import "core:math/rand"
import "core:time"

import "vendor:sdl3"

should_close_window :: proc
(
    event: sdl3.Event,
    targeted_window_id: sdl3.WindowID
) -> bool
{
    // Window close
    return event.type == .WINDOW_CLOSE_REQUESTED &&
           event.window.windowID == targeted_window_id
}

main :: proc() {
    WINDOW_WIDTH  :: 1920
    WINDOW_HEIGHT :: 1080
    ok := sdl3.Init(sdl3.InitFlags {
        .VIDEO
    })
    assert(ok)

    window: ^sdl3.Window
    renderer: ^sdl3.Renderer
    sdl3.CreateWindowAndRenderer(
        "Hello", 
        WINDOW_WIDTH, 
        WINDOW_HEIGHT, 
        sdl3.WindowFlags {},
        &window, 
        &renderer
    )

    surface := sdl3.CreateSurface(
        WINDOW_WIDTH,
        WINDOW_HEIGHT, 
        sdl3.PixelFormat.RGBA32
    )
    format := sdl3.GetPixelFormatDetails(sdl3.PixelFormat.RGBA32)

    last_tick := time.tick_now()

    cycle: u8 = 0
    for {
        cycle_dir := true

        sdl3.SetRenderDrawColor(
            renderer,
            255,
            255,
            255,
            255
        )
        sdl3.RenderClear(renderer)

        // Write pixels to surface
        for x in 0..<WINDOW_WIDTH {
            for y in 0..<WINDOW_HEIGHT {
                random_grayscale_val := u8(rand.int_max(255))

                sdl3.WriteSurfacePixel(
                    surface,
                    i32(x),
                    i32(y),
                    random_grayscale_val,
                    random_grayscale_val,
                    random_grayscale_val,
                    255
                )
            }
        }

        texture := sdl3.CreateTextureFromSurface(
            renderer,
            surface
        )
        sdl3.RenderTexture(
            renderer,
            texture,
            nil,
            nil
        )
        sdl3.RenderPresent(renderer)
        sdl3.DestroyTexture(texture)

        if cycle_dir {
            cycle = cycle + 1
        } else {
            cycle = cycle - 1
        }
        switch cycle_dir {
            case true:
                if cycle > 255 {
                    cycle = 254
                    cycle_dir = false
                }
            case false:
                if cycle == 0 {
                    cycle = 0
                    cycle_dir = true
                }
        }
        // fmt.printfln("%v", cycle)

        event: sdl3.Event
        exists := sdl3.PollEvent(&event)
        if exists {
            if should_close_window(event, sdl3.GetWindowID(window)) { break }
        }

        // update tick
        new_tick := time.tick_now()
        duration := time.tick_diff(last_tick, new_tick)
        last_tick = new_tick
        
        fps := 1.0 / time.duration_seconds(duration)
        new_title := fmt.ctprintf("%s [%f FPS]", "Hello", fps)
        sdl3.SetWindowTitle(window, new_title)
        delete_cstring(new_title, context.temp_allocator)
    }

    sdl3.DestroyRenderer(renderer)
    sdl3.DestroyWindow(window)
}
