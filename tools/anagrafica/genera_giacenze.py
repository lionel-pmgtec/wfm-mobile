"""Giacenze dei materiali PER MAGAZZINO, dai dati di anagrafiche.json.

anagrafiche.json (Backend-WFM-VIVA/data, solo lettura) elenca 15 materiali con
UN solo stock, nel loro magazzino predefinito, e 3 magazzini. Il tablet deve
poter scegliere fra più magazzini per ogni materiale: qui si completa il dato
che manca, in modo ripetibile:

- nel magazzino predefinito resta lo stock del backend (dato vero);
- negli altri magazzini dell'anagrafica il materiale c'e' per il 70% e per il
  40% di quello stock (arrotondati, almeno 1), in ordine di codice magazzino.

Quando il backend manderà `stockPerMagazzino`, quello ha la precedenza e questo
file non serve più.

Uso:  python tools/anagrafica/genera_giacenze.py
"""

import json
import os

BASE = os.path.join(os.path.dirname(__file__), '..', '..')
SORGENTE = os.path.join(BASE, 'Backend-WFM-VIVA', 'data', 'anagrafiche.json')
USCITA = os.path.join(BASE, 'assets', 'anagrafica', 'giacenze_magazzini.json')
QUOTE = [0.7, 0.4]  # negli altri magazzini, in ordine di codice


def arrotonda(x):
    return max(1, int(x + 0.5))


def main():
    d = json.load(open(SORGENTE, encoding='utf-8'))
    magazzini = sorted(w['code'] for w in d['warehouses'])
    giacenze = {}
    for m in d['materials']:
        stock = m['stockDisponibile']
        default = m['defaultWarehouseCode']
        altri = [c for c in magazzini if c != default]
        riga = {default: stock}
        for codice, quota in zip(altri, QUOTE):
            riga[codice] = arrotonda(stock * quota)
        giacenze[m['materialCode']] = dict(sorted(riga.items()))
    os.makedirs(os.path.dirname(USCITA), exist_ok=True)
    with open(USCITA, 'w', encoding='utf-8') as f:
        json.dump(giacenze, f, ensure_ascii=False, indent=1)
    print(len(giacenze), 'materiali ->', os.path.normpath(USCITA))


if __name__ == '__main__':
    main()
