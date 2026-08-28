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
