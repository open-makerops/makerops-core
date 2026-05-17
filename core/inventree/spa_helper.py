"""Template tag to render SPA imports."""

import json
import json.decoder
from pathlib import Path

from django import template
from django.conf import settings
from django.utils.safestring import mark_safe

import structlog

logger = structlog.get_logger('inventree')
register = template.Library()

FRONTEND_SETTINGS = json.dumps(settings.FRONTEND_SETTINGS)


@register.simple_tag
def spa_bundle(manifest_path: str | Path = '', app: str = 'web'):
    """Render SPA bundle."""

    def get_url(file: str) -> str:
        """Get static url for file."""
        return f'{settings.STATIC_URL}{app}/{file}'

    if manifest_path == '':
        manifest = Path(__file__).parent.parent.joinpath(
            'static/web/.vite/manifest.json'
        )
    else:
        manifest = Path(manifest_path)

    if not manifest.exists():
        # Try old path for manifest file
        manifest = Path(__file__).parent.parent.joinpath('static/web/manifest.json')

        # Final check - fail if manifest file not found
        if not manifest.exists():
            logger.error('Manifest file not found')
            return 'NOT_FOUND'

    try:
        manifest_data = json.load(manifest.open())
    except (TypeError, json.decoder.JSONDecodeError):
        logger.exception('Failed to parse manifest file')
        return ''

    return_string = ''
    # JS (based on index.html file as entrypoint)
    index = manifest_data.get('index.html')
    dynamic_files = index.get('dynamicImports', [])

    # Collect transitive static imports of dynamic chunks for preloading.
    # Without these hints the browser discovers and fetches them sequentially
    # after parsing each chunk, which pushes past the 1-second mount timeout.
    # ThemeContext-RRVgNtVr.js (400KB) is a static import of both MobileAppView
    # and DesktopAppView but is absent from the HTML, causing a cascade delay.
    preload_files: set = set()

    def collect_static_imports(chunk_key: str, visited: set = None) -> None:
        if visited is None:
            visited = set()
        if chunk_key in visited:
            return
        visited.add(chunk_key)
        chunk = manifest_data.get(chunk_key, {})
        for imp in chunk.get('imports', []):
            if imp == 'index.html':
                continue
            imp_chunk = manifest_data.get(imp, {})
            if imp_chunk.get('file'):
                preload_files.add(imp_chunk['file'])
            collect_static_imports(imp, visited)

    for dynamic_file in dynamic_files:
        collect_static_imports(dynamic_file)

    # Exclude files already emitted as <script type="module"> tags
    script_files = {
        manifest_data[f]['file'] for f in dynamic_files if f in manifest_data
    }

    # CSS link for the entry point (omitted by the upstream spa_bundle tag)
    for css_file in index.get('css', []):
        return_string += f'<link rel="stylesheet" href="{get_url(css_file)}">'

    # modulepreload hints so the browser fetches transitive deps in parallel
    # with the entry module instead of waiting to discover them sequentially
    for preload_file in sorted(preload_files - script_files):
        return_string += (
            f'<link rel="modulepreload" href="{get_url(preload_file)}">'
        )

    # Script tags
    imports_files = ''.join([
        f'<script type="module" src="{get_url(manifest_data[file]["file"])}"></script>'
        for file in dynamic_files
        if file in manifest_data
    ])
    return_string += (
        f'<script type="module" src="{get_url(index["file"])}"></script>'
        f'{imports_files}'
    )

    return mark_safe(return_string)


@register.simple_tag
def spa_settings():
    """Render settings for spa."""
    return mark_safe(
        f"""<script>window.INVENTREE_SETTINGS={FRONTEND_SETTINGS}</script>"""
    )
