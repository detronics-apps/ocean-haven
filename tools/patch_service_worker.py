"""Patches the exported game's service worker (build/site/play/index.service.worker.js) so
the installed app keeps the engine (index.wasm, ~39 MB) in a cache of its own, named after
the file's contents. Godot's worker drops everything on every new version, so each publish
made the phone download the whole engine again (slow, and on iOS it could stall); now an
update only downloads what changed (the game data, index.pck, well under 1 MB).
Run by tools/publish_pages.sh:  python tools/patch_service_worker.py build/site/play
"""
import hashlib
import pathlib
import sys

play = pathlib.Path(sys.argv[1])
worker = play / "index.service.worker.js"
engine = hashlib.sha1((play / "index.wasm").read_bytes()).hexdigest()[:12]
src = worker.read_text(encoding="utf-8")


def swap(old: str, new: str) -> None:
    global src
    if old not in src:
        sys.exit("patch_service_worker: Godot's service worker has changed; update this patch (%r)" % old[:60])
    src = src.replace(old, new, 1)


swap("const FULL_CACHE = CACHED_FILES.concat(CACHEABLE_FILES);",
     "const FULL_CACHE = CACHED_FILES.concat(CACHEABLE_FILES);\n"
     "// The engine, cached apart from the rest and kept across versions while it's unchanged.\n"
     "const ENGINE_FILE = 'index.wasm';\n"
     "const ENGINE_CACHE = CACHE_PREFIX + 'engine-%s';" % engine)
# Updating doesn't throw the engine away.
swap("key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME",
     "key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME && key !== ENGINE_CACHE")
# The engine comes from (and goes into) its own cache.
swap("\t\tif (isNavigate || isCacheable) {",
     "\t\tif (local === ENGINE_FILE) {\n"
     "\t\t\tevent.respondWith((async () => {\n"
     "\t\t\t\tconst engineCache = await caches.open(ENGINE_CACHE);\n"
     "\t\t\t\tconst cached = await engineCache.match(ENGINE_FILE);\n"
     "\t\t\t\tif (cached != null) {\n"
     "\t\t\t\t\treturn cached;\n"
     "\t\t\t\t}\n"
     "\t\t\t\tconst response = await self.fetch(event.request);\n"
     "\t\t\t\tif (response.ok) {\n"
     "\t\t\t\t\tengineCache.put(ENGINE_FILE, response.clone());\n"
     "\t\t\t\t}\n"
     "\t\t\t\treturn response;\n"
     "\t\t\t})());\n"
     "\t\t\treturn;\n"
     "\t\t}\n"
     "\t\tif (isNavigate || isCacheable) {")
# "Is everything cached?" looks for the engine in its own cache.
swap("const fullCache = await Promise.all(FULL_CACHE.map((name) => cache.match(name)));",
     "const engineCache = await caches.open(ENGINE_CACHE);\n"
     "\t\t\t\t\tconst fullCache = await Promise.all(FULL_CACHE.map((name) => (name === ENGINE_FILE ? engineCache : cache).match(name)));")
worker.write_text(src, encoding="utf-8")
print("Service worker patched (engine cache %s)." % engine)
