# Kernel

This is a simple, educational kernel implementation. I am currently creating this for educational purposes. However, I do plan on implementing the major parts of a real kernel - scheduling, system calls, memory management, drivers, etc. But I want to keep it simple and understandable. As you will see from the code, the goal is not to write a very clever, highly optimzed code. Rather, it is to take a raw machine - CPU and memory and IO devices and build a simple kernel to run user-space programs on top of. This will show how a kernel works, how programs work, how memory works, how IO works etc. It will be very rewarding to run real progarms on my own kernel. That is what makes it interesting. Don't be intimidated by online tutorials of how hard kernel development is. It's not that diffiult once you undestand the basic building blocks. Sure, you will need to (get to) learn how the CPU works, learn some assembly, set up data structures for the CPU, work with registers, learn weird legacy CPU quirks but it gets better the higher up you go (wait unti you get to C).

The `/res` directory contains a bunch of learning, useful resources about memory management, driver development, filesystem design etc.

## Where we are currently.
We have studied and understood the boot process, memory layout, designed our own filesystem, learned how drivers work, learned & implemented protected mode, gdt, set up the stack, learned about long mode, paging, entered protected mode, studied PML4, PDPT, PD, PT, learned about virtual memory, learned how to read from disk using ATA, learned a bit of assembly along the way. We have finished implementing our stage 1 boot sector (boot/stage1.asm) and also implemented our stage 2 boot sector code (boot/stage2.asm). We have jumped to our C kernel (kernel/main.c). We have done a lot of foundational work. It was fun, it was exciting and interesting. It wasn't as hard or scary as online tutorials often want us to believe. It just required a lot of patience and precision.

## Our current memory layout looks like this:

````
  0 KB    +--------------------------------------------+
          | 0 KB - 1 KB                                |
          | IVT - Interrupt Vector Table               |
  1 KB    +--------------------------------------------+
          | 1 KB - 1.25 KB                             |
          | BDA - BIOS Data Area                       |
 1.25 KB  +--------------------------------------------+
          |                                            |
          | 1.25 KB - 31 KB                            |
          |                                            |
          |                  Free RAM                  |
          |                                            |
          |                      ^                     |
          |                      |                     |
          |                      |                     |
          |                                            |
  31 KB   +--------------------------------------------+ <-- Stack Pointer
          | 31 KB - 31.5 KB                            |
          | Bootloader (stage 1)                       |
 31.5 KB  +--------------------------------------------+
          |                                            |
          | 31.5 KB - 95 KB                            |
          |                                            |
          |           Bootloader (stage 2)             |
          |                                            |
  95 KB   +--------------------------------------------+
          | 95 KB - 96 KB                              |
          | Free RAM                                   |
  96 KB   +--------------------------------------------+
          | 96 KB - 100 KB                             |
          | PML4 (Page Table)                          |
 100 KB   +--------------------------------------------+
          | 100 KB - 104 KB                            |
          | PDPT (Page Table)                          |
 104 KB   +--------------------------------------------+
          | 104 KB - 108 KB                            |
          | PD (Page Table)                            |
 108 KB   +--------------------------------------------+
          | 108 KB - 112 KB                            |
          | PT (Page Table)                            |
 112 KB   +--------------------------------------------+
          | 112 KB - 116 KB                            |
          | E820 Map                                   |
 116 KB   +--------------------------------------------+
          |                                            |
          |                                            |
          | 116 KB - 639 KB                            |
          |                                            |
          |                  Free RAM                  |
          |                                            |
          |                                            |
          |                                            |
 639 KB   +--------------------------------------------+
          | 639 KB - 640 KB                            |
          | EBDA - Extended BIOS Data Area             |
 640 KB   +--------------------------------------------+
          | 640 KB - 704 KB                            |
          | VGA Graphics Memory                        |
 704 KB   +--------------------------------------------+
          | 704 KB - 736 KB                            |
          | VGA Monochrome Text Memory                 |
 736 KB   +--------------------------------------------+
          | 736 KB - 768 KB                            |
          | VGA Color Text/Video Memory                |
 768 KB   +--------------------------------------------+
          |                                            |
          | 768 KB - 896 KB                            |
          | VGA Option ROM                             |
          |                                            |
 896 KB   +--------------------------------------------+
          | 896 KB - 960 KB                            |
          | SeaBIOS Runtime Memory                     |
 960 KB   +--------------------------------------------+
          | 960 KB - 1 MB                              |
          | SeaBIOS                                    |
   1 MB   +--------------------------------------------+
          |                                            |
          |                                            |
          | 1 MB - ...                                 |
          |                                            |
          |                  Free RAM                  |
          |                                            |
          |                                            |
          +--------------------------------------------+
````

## And our current disk layout looks like this:

````
  0 KB    +------------------------------------------+----------------------+
          | 0 KB - 0.5 KB                            |                      |
          | Boot Sector                              | /boot/stage1.bin     |
 0.5 KB   +------------------------------------------+----------------------+
          |                                          |                      |
          | 0.5 KB - 64 KB                           | /boot/stage2.bin     |
          |                                          |                      |
          |           Stage 2 Boot Sector            |                      |
          |                                          |                      |
  64 KB   +------------------------------------------+----------------------+
          |                                          |                      |
          |                                          |                      |
          | 64 KB - 10.6 MB                          | /fs/table            |
          |                                          |                      |
          |            File System Table             |                      |
          |                                          |                      |
          |                                          |                      |
          |                                          |                      |
          |                                          |                      |
10.6 MB   +------------------------------------------+----------------------+
          |                                          |                      |
          | 10.6 MB - 11.6 MB                        | /boot/kernel         |
          |                                          |                      |
          |                  Kernel                  |                      |
          |                                          |                      |
11.6 MB   +------------------------------------------+----------------------+
          |                                          |                      |
          |                                          |                      |
          | 11.6 MB - ...                            |                      |
          |                                          |                      |
          |               Free Space                 |                      |
          |                                          |                      |
          |                                          |                      |
          +------------------------------------------+----------------------+
````

## Filesystem / disk layout

For the disk I had this really cool idea of actually exposing the boot sector and the filesystem table to the users so they can actually peak into them. I want my kernel to be open, transparent and friendly to users. I don't want to hide anything from them. For now things are kept simple and hard coded - filesystem table is 10 MB, the kernel is 1 MB, stage 2 boot sector is 64 KB, stage 1 boot sector is 512 bytes. This makes it easier to work with them for now.

I have a very simple plan for my filesystem structure. It will support files and directories. But I wanted to design it as simple as possible so it is easy to resolve file paths etc. The plan is to implement a simple data structure like a table.

````
| id | name    | type  | start  | size  | parentDirId  |
| 1  | system  | dir   | 0      | 0     | null         |
| 2  | boot    | dir   | 0      | 0     | 1            |
| 3  | kernel  | file  | 14562  | 5489  | 1            |
````

Here is an example javascript, super simple implementation of how we might do a filesystem, we will convert this to C once we get there, this is just illustrative:

```js
/**
 * Illustrating a file system table and fs driver in javascript
 */

const fileSystemTable = [{
        id: 1,
        name: 'system',
        type: 'dir',
        start: 0,
        size: 0,
        parentDirId: null,
    },

    {
        id: 2,
        name: 'boot',
        type: 'dir',
        start: 0,
        size: 0,
        parentDirId: 1,
    },

    {
        id: 3,
        name: 'kernel',
        type: 'file',
        start: 14562,
        size: 5489,
        parentDirId: 2,
    },
]

/**
 * Simple demonstration of how file lookup works
 * You can ignore this.
 */
const simpleOpen = (path) => {
    /**
     * parts = ['', 'system', 'boot', 'kernel']
     */
    const parts = path.split('/')

    const systemDir = fileSystemTable.find(fsEntry => fsEntry.name === parts[1])
    const bootDir = fileSystemTable.find(fsEntry => fsEntry.name === parts[2] && fsEntry.parentDirId === systemDir.id)
    const kernelFile = fileSystemTable.find(fsEntry => fsEntry.name === parts[3] && fsEntry.parentDirId === bootDir.id)

    return kernelFile
}

/**
 * Proper open implementation
 * 
 * We beging by splitthe the path on '/' (directory seperator).
 * Then we loop through each part - ['system', 'boot', 'kernel'] and we begin
 * by first finding the root (parentDirId = null). Once we find it, we update
 * the parentDirId with the found entry's id and continue to the next part. Now
 * parentDirId is no longer null but e.g. 1 and we try to find the entry with
 * name and parentDirId. Every time we find it we update our foundEntry and parentDirId.
 * 
 * At the end we have looped over each file path part and foundEntry is the last
 * found entry which is the actual file we were looking for.
 * 
 * Example: /system/boot/kernel
 *
 * parentDirId = null

 * find:
 * name = system
 * parentDirId = null
 * ↓
 * found id = 1

 * find:
 * name = boot
 * parentDirId = 1
 * ↓
 * found id = 2

 * find:
 * name = kernel
 * parentDirId = 2
 * ↓
 * found file
 */
const open = (path) => {
    // ['system', 'boot', 'kernel']
    const pathParts = path.split('/').filter(Boolean)

    let foundEntry
    let parentDirId = null

    for (let i = 0; i < pathParts.length; i++) {
        foundEntry = fileSystemTable.find(fsEntry => {
            return fsEntry.name === pathParts[i] && fsEntry.parentDirId === parentDirId
        })

        parentDirId = foundEntry.id
    }

    return foundEntry
}


// console.log('simpleOpen', simpleOpen('/system/boot/kernel'))
console.log('open', open('/system/boot/kernel'))
```

Of course we will implement the filesystem driver in C, this is just an illustrative example in JavaScript for how we imagine this might work. The C code might be even simpler.

## E820 memory map:

We also currently have retrieved the memory map from BIOS and we will use that to construct a memory bitmap so we can do memory allocation and managemnt.

## ABI / Systemcall API:

When we eventually get to implementing the systemcall interface, I think it would be a good idea to make this Unix/Linux compatible. We do not need to come up with our own syscall or binary executable interface.

## Build script

Our build script is pretty simple right now. It compiles the kernel and both stage 1 and stage 2 boot sectors. It then creates a disk by writing the stage 1 boot sector to it at the beginning, then right after it, it writes stage 2 and then it leaves a 10 MB gap for the filesystem table and then it writes the kernel. Then it just fires up QEMU with our OS.

## Goal:
The goal for now is to be able to run at least 2 programs simultaneously (time-sharing, scheduling) on our kenrel from user-space. Our kernel will start its first user-space program just like Linux at a predefined path (e.g. /bin/init) and then the init program will start 2 programs in parallel. Perhaps /bin/snake and /bin/tic-tac-toe and have them split-screen share the screen to see that multitasking works. It will require FS path resolution, memory management, scheduling, system calls, some primitive graphics, driveres, mmap, etc. It should be a good demonstartion of our operating system.

Perhaps we can create a primitive desktop environment at that point as well.
