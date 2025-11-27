const http = require('http');
const port = 3000;

const server = http.createServer((req, res) => {
    res.writeHead(200, { "Content-Type": "text/html" });

    res.end(`
        <html>
        <body>
          <h1>Request Headers After oauth2-proxy</h1>
          <pre>${JSON.stringify(req.headers, null, 2)}</pre>
        </body>
        </html>
      `);
});

server.listen(port, () => {
    console.log("Header dump server running on port", port);
});