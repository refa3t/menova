import http from 'http'; import fs from 'fs'; import path from 'path';
const root = process.argv[2]; const port = Number(process.argv[3] ?? 8080);
const types = {'.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.html':'text/html','.json':'application/json','.png':'image/png','.otf':'font/otf','.ttf':'font/ttf','.mp3':'audio/mpeg'};
http.createServer((q, r) => {
  let p = path.join(root, decodeURIComponent(q.url.split('?')[0]));
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(root, 'index.html');
  r.writeHead(200, {'content-type': types[path.extname(p)] ?? 'application/octet-stream'});
  fs.createReadStream(p).pipe(r);
}).listen(port, () => console.log('on', port));
