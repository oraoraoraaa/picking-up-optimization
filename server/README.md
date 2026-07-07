# pickup-op-server

Thin HTTP gateway around the [`core/`](../core) optimization engine. It holds
the AMap **Web Service** key server-side, runs the Rust engine, and returns a
display-ready `RecommendationSet` so the mobile app never has to ship the
billable key. Identical requests are cached briefly across all users.

## Endpoints

| Method | Path       | Description                                                       |
| ------ | ---------- | ----------------------------------------------------------------- |
| GET    | `/health`  | Liveness probe, returns `ok`.                                     |
| POST   | `/analyze` | Body = `Scenario` JSON; returns `RecommendationSet` JSON.         |

`POST /analyze` request body:

```json
{
  "driver":    { "name": "Lujiazui",       "lon": 121.5086, "lat": 31.2454 },
  "passenger": { "name": "People's Square", "lon": 121.4737, "lat": 31.2304 },
  "city": "上海"
}
```

`city` is optional — when omitted the server reverse-geocodes the passenger to
get the citycode needed for transit planning. If `APP_TOKEN` is configured,
send it as the `X-App-Token` header. The response carries an `X-Cache: HIT|MISS`
header.

## Configuration (environment variables)

See [`.env.example`](.env.example): `AMAP_KEY`, `APP_TOKEN`, `CACHE_TTL_SECS`,
`BIND_ADDR`, `PORT`.

## Run locally

```bash
# from the repository root (workspace)
AMAP_KEY=your_web_service_key APP_TOKEN=dev-token PORT=8080 \
  cargo run --release -p pickup-op-server

curl -s -X POST http://127.0.0.1:8080/analyze \
  -H 'content-type: application/json' \
  -H 'x-app-token: dev-token' \
  -d '{"driver":{"name":"A","lon":121.5086,"lat":31.2454},
       "passenger":{"name":"B","lon":121.4737,"lat":31.2304}}'
```

## Run with Docker

```bash
# build context is the repo root because this crate depends on ../core
docker build -t pickup-op-server .
docker run --rm -p 8080:8080 \
  -e AMAP_KEY=your_web_service_key \
  -e APP_TOKEN=change_me \
  pickup-op-server
```

See [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md) for hosting and for pointing
the Flutter app at the deployed URL.
