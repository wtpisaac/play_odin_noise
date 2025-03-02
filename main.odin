package hellope

import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:time"
import "core:thread"
import "core:slice"

import "vendor:sdl3"

WINDOW_WIDTH  :: 1920
WINDOW_HEIGHT :: 1080
WINDOW_PIXELS_FLAT_COUNT :: WINDOW_WIDTH * WINDOW_HEIGHT * 4 /* RGBA */
GENERATION_THREAD_COUNT :: 8
GENERATION_THREAD_SLICE_SIZE :: WINDOW_PIXELS_FLAT_COUNT / GENERATION_THREAD_COUNT;

start := time.tick_now()
log_now :: proc() {
    now := time.tick_now()
    fmt.printfln("%v", time.duration_milliseconds(time.tick_diff(start, now)))
}

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

GenerationTaskData :: struct {
    pixels: []u8
}

random_pixel_generation_task_proc :: proc(
    task: thread.Task
) {
    task_data := (^GenerationTaskData)(task.data)
    pixels := task_data.pixels

    for p := 0; p < slice.length(task_data.pixels); p += 4 {
        rand_color_val := u8(rand.int_max(255))

        pixels[p] = rand_color_val
        pixels[p+1] = rand_color_val
        pixels[p+2] = rand_color_val
        pixels[p+3] = 255
    }
}

main :: proc() {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
        if len(track.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        if len(track.bad_free_array) > 0 {
            fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
            for entry in track.bad_free_array {
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }

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
    // cycle: u8 = 0

    pool: thread.Pool
    thread.pool_init(
        &pool,
        context.temp_allocator,
        8
    )
    thread.pool_start(&pool)

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
        surface_pixels_slice := slice.bytes_from_ptr(
            surface.pixels, 
            WINDOW_PIXELS_FLAT_COUNT
        )

        // Spawn threads
        fmt.println("START THREADS")
        log_now()
        task_data_arr := [GENERATION_THREAD_COUNT]GenerationTaskData {};
        for i in 0..<GENERATION_THREAD_COUNT {
            // if i != 1 {continue}
            task_data_arr[i] = GenerationTaskData {
                pixels = surface_pixels_slice[GENERATION_THREAD_SLICE_SIZE*i : 
                                              GENERATION_THREAD_SLICE_SIZE*(i + 1)]
            }

            thread.pool_add_task(
                &pool,
                mem.panic_allocator(),
                random_pixel_generation_task_proc,
                &task_data_arr[i],
            )
        }
        thread.pool_finish(&pool)
        fmt.println("END THREADS")
        log_now()

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
        fmt.println("END RENDER")
        log_now()
        fmt.println("STOP TRACK")
        sdl3.DestroyTexture(texture)

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

        // free_all(context.temp_allocator)
    }

    sdl3.DestroyRenderer(renderer)
    sdl3.DestroyWindow(window)
}
