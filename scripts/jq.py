import json 

with open('scripts/data.json', 'r') as f:
    data = json.load(f)

print("Usernames:", [u['name'] for u in data['users']])

active_users = [u for u in data['users'] if u['active']]
print("Active Users:", active_users)

print("Project Name:", data['project']['name'])

data['project']['tools'].append("Kubernetes")

with open('scripts/data_updated.json', 'w') as f:
    json.dump(data, f, indent=4)

print("updated tools", data['project']['tools'])

admins = [u['name'] for u in data['users'] if u['role'] == 'admin']
print("Admin Users:", admins)