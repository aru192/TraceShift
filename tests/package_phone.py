"""Prepare a static HTTPS site; gzip keeps the engine asset below host file limits."""
from pathlib import Path
import gzip, shutil
root=Path(__file__).resolve().parents[1]
out=root/'phone-site/dist'
out.mkdir(parents=True,exist_ok=True)
for p in (root/'build/web').iterdir():
 if p.suffix in ('.import', '.wasm') or p.name.startswith('.'): continue
 if p.is_file():shutil.copy2(p,out/p.name)
wasm=(root/'build/web/index.wasm').read_bytes()
(out/'index.wasm.gz').write_bytes(gzip.compress(wasm,mtime=0))
loader='''// Serve the compressed engine as a streaming WebAssembly response.
const nativeFetch = window.fetch.bind(window);
window.fetch = async (input, options) => {
 const url = new URL(typeof input === 'string' ? input : input.url, location.href);
 if (url.origin === location.origin && url.pathname.endsWith('/index.wasm')) {
  url.pathname += '.gz';
  const result = await nativeFetch(url.href, options);
  if (!result.ok) throw new Error('ゲームの読み込みに失敗しました。再読み込みしてください。');
  return new Response(result.body.pipeThrough(new DecompressionStream('gzip')), {
   headers: { 'Content-Type': 'application/wasm', 'Content-Length': 'WASM_SIZE' }
  });
 }
 return nativeFetch(input, options);
};
'''.replace('WASM_SIZE',str(len(wasm)))
(out/'compressed-engine.js').write_text(loader)
p=out/'index.html';s=p.read_text().replace('<html lang="en">','<html lang="ja">').replace('<title>TRACE SHIFT</title>','<title>TRACE SHIFT · DUET</title>').replace('<script src="index.js"></script>','<script src="compressed-engine.js"></script>\n\t\t<script src="index.js"></script>');p.write_text(s)
p=out/'index.service.worker.js';s=p.read_text().replace('"index.wasm"','"index.wasm.gz"').replace('"index.html","index.js"','"index.html","compressed-engine.js","index.js"');s=s.replace('cache.addAll(CACHED_FILES)', 'cache.addAll(CACHED_FILES).then(() => self.skipWaiting())')
s += '\nself.addEventListener(\"activate\", event => event.waitUntil(self.clients.claim()));\n'
p.write_text(s)
shutil.copy2(root/'assets/fonts/OFL.txt',out/'FONT-LICENSE.txt')
print('Static site prepared:',sum(p.stat().st_size for p in out.iterdir() if p.is_file()),'bytes')
