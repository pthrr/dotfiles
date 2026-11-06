// Live Plotly figures in the browser: show(name, figure) publishes a figure to http://localhost:8000.
// Run the calling script under `node --watch`; each save reruns it and the page redraws in place.
import http from "node:http";
import { Buffer } from "node:buffer";

export type Figure = { data: object[]; layout?: object; config?: object };

const page = `<!doctype html>
<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
<script>
    new EventSource("/events").onmessage = (event) => {
        const { name, figure } = JSON.parse(event.data);
        let element = document.getElementById(name);

        if (!element) {
            element = document.createElement("div");
            element.id = name;
            element.style.height = "60vh";
            document.body.append(element);
        }

        figure.layout = { uirevision: 1, ...figure.layout }; // uirevision: keep zoom across updates
        Plotly.react(element, figure);
    };
</script>`;

const clients = new Set<http.ServerResponse>();
const figures = new Map<string, string>(); // name -> latest message, for late joiners
let server: http.Server | undefined;

function serve(): http.Server {
    return http.createServer((request, response) => {
        if (request.url === "/events") {
            response.writeHead(200, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache" });
            response.write("retry: 300\n\n"); // reconnect 300 ms after a --watch restart

            for (const message of figures.values()) {
                response.write(message);
            }

            clients.add(response);
            request.on("close", () => clients.delete(response));
            return;
        }

        response.end(page);
    }).listen(8000);
}

// Plotly's base64 form for typed arrays; JSON.stringify would turn them into {"0": ..., "1": ...}.
const dtypes: Record<string, string> = {
    Float64Array: "f8",
    Float32Array: "f4",
    Int32Array: "i4",
    Uint32Array: "u4",
    Int16Array: "i2",
    Uint16Array: "u2",
    Int8Array: "i1",
    Uint8Array: "u1",
    Uint8ClampedArray: "u1c",
};

function encodeTypedArray(_key: string, value: unknown): unknown {
    if (!ArrayBuffer.isView(value) || !(value.constructor.name in dtypes)) {
        return value;
    }

    const bdata = Buffer.from(value.buffer, value.byteOffset, value.byteLength).toString("base64");
    return { dtype: dtypes[value.constructor.name], bdata };
}

// A new name adds a figure to the page, a repeated name updates it in place. The server starts on
// the first call, so importing this module opens no port.
export function show(name: string, figure: Figure) {
    server ??= serve();
    const message = `data: ${JSON.stringify({ name, figure }, encodeTypedArray)}\n\n`;
    figures.set(name, message);

    for (const client of clients) {
        client.write(message);
    }
}
