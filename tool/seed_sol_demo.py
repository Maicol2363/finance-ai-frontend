"""Append deterministic demo data only to the isolated local SOL test user.

Credentials are read from a private file and never printed or checkpointed.
The checkpoint prevents repeated runs from duplicating completed POSTs.
"""

import argparse
import calendar
from collections import Counter
from datetime import date
import json
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


class DemoSeeder:
    def __init__(self, credentials, checkpoint, cutoff):
        self.api = "http://127.0.0.1:8000"
        if urlsplit(self.api).hostname != "127.0.0.1":
            raise ValueError("Only the local synthetic environment is allowed")
        self.credentials = json.loads(Path(credentials).read_text())
        email = self.credentials["email"]
        if not (email.startswith("sol-android-") and email.endswith("@example.com")):
            raise ValueError("This is not the isolated SOL fixture identity")
        self.checkpoint = Path(checkpoint)
        self.cutoff = cutoff
        self.token = None
        login = self.request("/api/v1/auth/login", {**self.credentials, "platform": "android"})
        self.token = login["access_credential"]
        self.owner = login["user"]["id"]
        self.state = {"owner": self.owner, "records": {}}
        if self.checkpoint.exists():
            self.state = json.loads(self.checkpoint.read_text())
            if self.state["owner"] != self.owner:
                raise ValueError("Checkpoint belongs to another identity")

    def request(self, path, payload=None):
        headers = {"Content-Type": "application/json"}
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        body = None if payload is None else json.dumps(payload).encode()
        with urlopen(Request(self.api + path, data=body, headers=headers), timeout=30) as response:
            return json.load(response)

    def append(self, tag, path, payload):
        if tag in self.state["records"]:
            return self.state["records"][tag]
        created = self.request(path, payload)
        identifier = created["id"]
        self.state["records"][tag] = identifier
        self.checkpoint.parent.mkdir(parents=True, exist_ok=True)
        self.checkpoint.write_text(json.dumps(self.state, indent=2))
        self.checkpoint.chmod(0o600)
        return identifier

    def seed(self):
        accounts = self.request("/api/v1/accounts?include_inactive=true")["accounts"]
        cash = next(a["id"] for a in accounts if a["name"] == "SOL synthetic cash")
        bank = self.append("account:cop-bank", "/api/v1/accounts", {
            "name": "SOL demo banco COP", "type": "bank", "currency_code": "COP",
            "opening_balance": "2500000.00",
        })
        usd = self.append("account:usd", "/api/v1/accounts", {
            "name": "SOL demo dólares", "type": "savings", "currency_code": "USD",
            "opening_balance": "0.00",
        })
        definitions = [
            ("Alimentación demo", "green", "food"),
            ("Transporte demo", "blue", "transport"),
            ("Servicios demo", "orange", "bills"),
            ("Salud demo", "red", "health"),
            ("Ocio demo", "purple", "entertainment"),
            ("Educación demo", "teal", "education"),
        ]
        categories = [self.append(f"category:{i}", "/api/v1/categories", {
            "name": name, "color": color, "icon": icon,
        }) for i, (name, color, icon) in enumerate(definitions)]
        salary = self.append("source:salary", "/api/v1/income-sources", {"name": "Salario demo"})
        freelance = self.append("source:freelance", "/api/v1/income-sources", {"name": "Freelance demo"})
        first_index = self.cutoff.year * 12 + self.cutoff.month - 1 - 5
        for index in range(6):
            year, month0 = divmod(first_index + index, 12)
            month = month0 + 1
            days = min(calendar.monthrange(year, month)[1],
                       self.cutoff.day if (year, month) == (self.cutoff.year, self.cutoff.month) else 31)
            prefix = f"{year:04}-{month:02}"
            for day, account, amount, source in [
                (2, bank, 2800000 + index * 100000, salary),
                (10, bank, 450000 + (index % 3) * 190000, freelance),
                (2, usd, 350 + index * 25, freelance),
            ]:
                if day <= days:
                    self.append(f"income:{prefix}:{day}:{account}", "/api/v1/incomes", {
                        "account_id": account, "amount": f"{amount:.2f}",
                        "date": f"{prefix}-{day:02}", "income_source_id": source,
                        "description": "Ingreso sintético SOL de demostración",
                    })
            self.append(f"transfer:{prefix}:cash", "/api/v1/transfers", {
                "source_account_id": bank, "destination_account_id": cash,
                "source_amount": "1200000.00", "date": f"{prefix}-03",
                "description": "Transferencia sintética SOL: banco a efectivo",
            })
            for day in range(2, min(days, 28) + 1, 2):
                category = categories[(day // 2 + index) % len(categories)]
                amount = 12000 + ((day + index * 7) % 11) * 3900
                self.expense(f"{prefix}-{day:02}:routine", cash, amount, category,
                             f"{prefix}-{day:02}", "Compra demo SOL")
            for day, amount, category, merchant in [
                (5, 250000 + index * 5000, categories[2], "Servicios demo SOL"),
                (12, 185000 + index * 4500, categories[0], "Mercado demo SOL"),
                (18, 92000 + index * 2000, categories[1], "Transporte demo SOL"),
            ]:
                if day <= days:
                    self.expense(f"{prefix}-{day:02}:bill", cash, amount, category,
                                 f"{prefix}-{day:02}", merchant)
            for day, amount in [(4, 18.50), (10, 45.00), (16, 12.75), (23, 60.00)]:
                if day <= days:
                    self.expense(f"{prefix}-{day:02}:usd", usd, amount, categories[5],
                                 f"{prefix}-{day:02}", "Suscripción demo USD")
            if days >= 20:
                self.append(f"transfer:{prefix}:cross", "/api/v1/transfers", {
                    "source_account_id": usd, "destination_account_id": bank,
                    "source_amount": "50.00", "destination_amount": "200000.00",
                    "date": f"{prefix}-20",
                    "description": "Transferencia demo SOL: importes declarados, tasa ficticia",
                })
        for i, amount in [(0, 400000), (1, 200000), (2, 350000)]:
            self.append(f"budget:cop:{i}", "/api/v1/budgets", {
                "name": definitions[i][0], "category_id": categories[i],
                "amount": f"{amount:.2f}", "currency_code": "COP", "period": "monthly",
            })
        self.append("budget:usd", "/api/v1/budgets", {
            "name": "Educación demo USD", "category_id": categories[5],
            "amount": "150.00", "currency_code": "USD", "period": "monthly",
        })
        counts = Counter(tag.split(":")[0] for tag in self.state["records"])
        print(json.dumps({"months": 6, "cutoff": self.cutoff.isoformat(), "created_records": counts}, ensure_ascii=False))

    def expense(self, tag, account, amount, category, day, merchant):
        self.append("expense:" + tag, "/api/v1/expenses", {
            "account_id": account, "amount": f"{amount:.2f}", "merchant": merchant,
            "occurred_at": day + "T12:00:00-05:00", "category_id": category,
            "note": "Dato sintético SOL; cuenta de prueba local; no es un gasto real",
        })


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", required=True)
    parser.add_argument("--checkpoint", default="build/sol-evidence/demo-seed-checkpoint.json")
    parser.add_argument("--cutoff", default="2026-10-13")
    args = parser.parse_args()
    DemoSeeder(args.credentials, args.checkpoint, date.fromisoformat(args.cutoff)).seed()
