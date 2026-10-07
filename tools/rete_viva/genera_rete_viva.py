"""Genera la mappa della rete Viva Servizi (zona Ancona 60128) per l'app.

Uscita: assets/rete_viva/rete_viva_ancona.geojson, letto dalla mappa del tablet.

Da dove vengono i dati:
- vie e edifici: OpenStreetMap (API ufficiale, riquadro BBOX), (c) OpenStreetMap
  contributors, licenza ODbL;
- indirizzo dei contatori: quello dell'edificio in OSM (addr:*), altrimenti il
  civico OSM piu' vicino (entro 25 m), altrimenti la geocodifica inversa Esri
  (reverseGeocode, pubblica). Ogni contatore ha quindi un indirizzo reale.

Cosa costruisce:
- condotte lungo le vie (rosse = adduzione sulle vie principali, verdi =
  distribuzione), con materiale e diametro come sulla mappa Viva;
- un contatore per edificio, sul lato dell'edificio verso la condotta;
- l'allaccio (tratteggio rosa) dal contatore alla condotta;
- i riduttori di pressione negli incroci della rete di adduzione.

Uso:  python tools/rete_viva/genera_rete_viva.py
"""

import json
import math
import os
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor

BBOX = (13.5030, 43.5955, 13.5190, 43.6030)  # ovest, sud, est, nord
COMUNE = 'Ancona'
USCITA = os.path.join(os.path.dirname(__file__), '..', '..', 'assets',
                      'rete_viva', 'rete_viva_ancona.geojson')

TIPI_STRADA = {'primary', 'secondary', 'tertiary', 'residential',
               'unclassified', 'living_street', 'pedestrian'}
PRINCIPALI = {'primary', 'secondary', 'tertiary'}
MATERIALI_ADDUZIONE = ['Acciaio 100', 'Ghisa sferoidale 150', 'Acciaio 200',
                       'Fibrocemento 100', 'Ghisa sferoidale 100']
MATERIALI_DISTRIBUZIONE = ['PEAD 90', 'PEAD 110', 'PEAD 50', 'PVC 90',
                           'Ghisa grigia 50', 'PEAD 63', 'PEAD 32',
                           'Acciaio 65', 'PEAD Non noto', 'Acciaio 80']
EDIFICI_ESCLUSI = {'garage', 'garages', 'shed', 'roof', 'carport', 'hut',
                   'service', 'transformer_tower', 'ruins', 'construction'}

UA = {'User-Agent': 'wfm-app-rete-viva/1.0'}


def scarica(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


# ─── Geometria (metri locali, sufficiente su 1-2 km) ─────────────────────────

LAT0 = (BBOX[1] + BBOX[3]) / 2
MX = 111320 * math.cos(math.radians(LAT0))
MY = 110540


def a_metri(lon, lat):
    return (lon * MX, lat * MY)


def da_metri(x, y):
    return (x / MX, y / MY)


def proietta_su_segmento(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0 if l2 == 0 else max(0, min(1, ((p[0] - ax) * dx + (p[1] - ay) * dy) / l2))
    q = (ax + t * dx, ay + t * dy)
    return q, math.dist(p, q)


def punto_piu_vicino(p, linee):
    """(punto, distanza, indice linea) sulla linea piu' vicina a p."""
    migliore = (None, float('inf'), -1)
    for i, linea in enumerate(linee):
        for a, b in zip(linea, linea[1:]):
            q, d = proietta_su_segmento(p, a, b)
            if d < migliore[1]:
                migliore = (q, d, i)
    return migliore


def area(poligono):
    s = 0
    for (x1, y1), (x2, y2) in zip(poligono, poligono[1:] + poligono[:1]):
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


# ─── Esri reverseGeocode ─────────────────────────────────────────────────────

def indirizzo_esri(lon, lat):
    q = urllib.parse.urlencode({'location': f'{lon},{lat}', 'langCode': 'ITA',
                                'outSR': 4326, 'f': 'json'})
    try:
        d = json.loads(scarica(
            'https://geocode.arcgis.com/arcgis/rest/services/World/'
            'GeocodeServer/reverseGeocode?' + q))
        a = d.get('address') or {}
        completo = (a.get('Address') or '').strip()
        civico = (a.get('AddNum') or '').strip()
        if not completo or not (a.get('City') or '').strip():
            return None
        via = completo[:-len(civico) - 1] if civico and completo.endswith(' ' + civico) else completo
        return {'via': via, 'civico': civico, 'cap': (a.get('Postal') or '').strip()}
    except Exception:
        return None


def main():
    print('Scarico OpenStreetMap…')
    xml = scarica('https://api.openstreetmap.org/api/0.6/map?bbox=' +
                  ','.join(str(v) for v in BBOX))
    root = ET.fromstring(xml)
    tag = lambda e: {t.get('k'): t.get('v') for t in e.findall('tag')}
    nodi = {n.get('id'): (float(n.get('lon')), float(n.get('lat')))
            for n in root.findall('node')}
    dentro = lambda lon, lat: BBOX[0] <= lon <= BBOX[2] and BBOX[1] <= lat <= BBOX[3]

    # ── Condotte lungo le vie ────────────────────────────────────────────────
    vie = []  # (nome, principale, [id nodi])
    for w in root.findall('way'):
        t = tag(w)
        h = t.get('highway')
        if h not in TIPI_STRADA and not (h == 'service' and t.get('name')):
            continue
        ids = [nd.get('ref') for nd in w.findall('nd') if nd.get('ref') in nodi]
        if len(ids) >= 2:
            vie.append((t.get('name', ''), h in PRINCIPALI, ids))

    nomi = sorted({n for n, _, _ in vie if n})
    def materiale(nome, principale, i):
        lista = MATERIALI_ADDUZIONE if principale else MATERIALI_DISTRIBUZIONE
        k = nomi.index(nome) if nome else i
        return lista[k % len(lista)]

    features = []
    linee_m = []
    for i, (nome, principale, ids) in enumerate(vie):
        coords = [nodi[x] for x in ids]
        linee_m.append([a_metri(*c) for c in coords])
        features.append({'type': 'Feature',
                         'geometry': {'type': 'LineString', 'coordinates': [
                             [round(lo, 6), round(la, 6)] for lo, la in coords]},
                         'properties': {'tipo': 'condotta',
                                        'rete': 'adduzione' if principale else 'distribuzione',
                                        'materiale': materiale(nome, principale, i),
                                        'via': nome}})
    print(f'Condotte: {len(vie)}')

    # ── Riduttori negli incroci della rete di adduzione ─────────────────────
    uso = {}
    for nome, principale, ids in vie:
        for x in set(ids):
            uso.setdefault(x, []).append((nome, principale))
    riduttori = []
    for x, vie_nodo in uso.items():
        if len(vie_nodo) < 3 or not any(p for _, p in vie_nodo):
            continue
        pm = a_metri(*nodi[x])
        if all(math.dist(pm, a_metri(*nodi[r])) > 150 for r in riduttori) and dentro(*nodi[x]):
            riduttori.append(x)
    for i, x in enumerate(riduttori, 1):
        nomi_via = sorted({n for n, _ in uso[x] if n})
        features.append({'type': 'Feature',
                         'geometry': {'type': 'Point', 'coordinates': [
                             round(nodi[x][0], 6), round(nodi[x][1], 6)]},
                         'properties': {'tipo': 'riduttore', 'codice': f'AN{i:02d}',
                                        'via': ' / '.join(nomi_via[:2]),
                                        'comune': COMUNE}})
    print(f'Riduttori: {len(riduttori)}')

    # ── Civici OSM (nodi o edifici con addr:housenumber) ─────────────────────
    civici = []
    for e in list(root.findall('node')) + list(root.findall('way')):
        t = tag(e)
        if 'addr:housenumber' not in t or 'addr:street' not in t:
            continue
        if e.tag == 'node':
            p = nodi.get(e.get('id'))
        else:
            pts = [nodi[nd.get('ref')] for nd in e.findall('nd') if nd.get('ref') in nodi]
            p = (sum(x for x, _ in pts) / len(pts), sum(y for _, y in pts) / len(pts)) if pts else None
        if p:
            civici.append((a_metri(*p), {'via': t['addr:street'],
                                         'civico': t['addr:housenumber'],
                                         'cap': t.get('addr:postcode', '')}))

    # ── Un contatore per edificio ────────────────────────────────────────────
    edifici = []
    for w in root.findall('way'):
        t = tag(w)
        if 'building' not in t or t['building'] in EDIFICI_ESCLUSI:
            continue
        pts = [nodi[nd.get('ref')] for nd in w.findall('nd') if nd.get('ref') in nodi]
        if len(pts) < 4:
            continue
        poli = [a_metri(*p) for p in pts[:-1]]
        if area(poli) < 40:
            continue
        cx = sum(x for x, _ in poli) / len(poli)
        cy = sum(y for _, y in poli) / len(poli)
        if not dentro(*da_metri(cx, cy)):
            continue
        ind = None
        if 'addr:housenumber' in t and 'addr:street' in t:
            ind = {'via': t['addr:street'], 'civico': t['addr:housenumber'],
                   'cap': t.get('addr:postcode', '')}
        edifici.append({'poli': poli, 'centro': (cx, cy), 'ind': ind})

    for e in edifici:
        if e['ind'] is None and civici:
            p, ind = min(civici, key=lambda c: math.dist(c[0], e['centro']))
            if math.dist(p, e['centro']) <= 25:
                e['ind'] = dict(ind)

    mancanti = [e for e in edifici if e['ind'] is None]
    print(f'Edifici: {len(edifici)}; indirizzo da Esri per {len(mancanti)}…')
    with ThreadPoolExecutor(8) as ex:
        for e, ind in zip(mancanti, ex.map(
                lambda e: indirizzo_esri(*da_metri(*e['centro'])), mancanti)):
            e['ind'] = ind

    n = 0
    for e in edifici:
        ind = e['ind']
        if not ind or not ind.get('via'):
            continue  # senza indirizzo reale nessun contatore
        # Il contatore sta sul lato dell'edificio verso la condotta piu' vicina.
        q, d, _ = punto_piu_vicino(e['centro'], linee_m)
        if q is None or d > 80:
            continue
        bordo, _, _ = punto_piu_vicino(q, [e['poli'] + e['poli'][:1]])
        cx, cy = e['centro']
        c = (bordo[0] + (cx - bordo[0]) * 0.15, bordo[1] + (cy - bordo[1]) * 0.15)
        attacco, _, _ = punto_piu_vicino(c, linee_m)
        n += 1
        lon, lat = da_metri(*c)
        features.append({'type': 'Feature',
                         'geometry': {'type': 'LineString', 'coordinates': [
                             [round(lon, 6), round(lat, 6)],
                             [round(v, 6) for v in da_metri(*attacco)]]},
                         'properties': {'tipo': 'allaccio'}})
        features.append({'type': 'Feature',
                         'geometry': {'type': 'Point', 'coordinates': [
                             round(lon, 6), round(lat, 6)]},
                         'properties': {'tipo': 'contatore', 'id': f'C{n:04d}',
                                        'via': ind['via'], 'civico': ind['civico'],
                                        'cap': ind.get('cap') or '60128',
                                        'comune': COMUNE}})
    print(f'Contatori: {n}')

    os.makedirs(os.path.dirname(USCITA), exist_ok=True)
    with open(USCITA, 'w', encoding='utf-8') as f:
        json.dump({'type': 'FeatureCollection',
                   'fonte': 'OpenStreetMap (ODbL) + Esri reverseGeocode',
                   'bbox': list(BBOX), 'features': features},
                  f, ensure_ascii=False, separators=(',', ':'))
    print('Scritto', os.path.normpath(USCITA))


if __name__ == '__main__':
    sys.exit(main())
