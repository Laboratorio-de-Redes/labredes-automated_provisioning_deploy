import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from ldap3 import Server, Connection, ALL
from ldap3.core.exceptions import LDAPBindError

app = Flask(__name__)
CORS(app)

# =========================
# CONFIGURAÇÃO DO LDAP (VM9)
# =========================
# ALTERADO: o IP do servidor LDAP agora é lido de uma variável de ambiente
# (LDAP_SERVER), com o valor de produção como fallback padrão — assim o
# mesmo código funciona tanto em produção quanto em qualquer ambiente de
# teste isolado, bastando injetar a variável via docker-compose/Ansible.
LDAP_SERVER = os.getenv('LDAP_SERVER', 'ldap://192.168.10.108:389')
BASE_DN = 'dc=labredes,dc=local'
OU_USERS = 'ou=Users'

# =========================
# ROTA DE LOGIN
# =========================

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "status": "online",
        "mensagem": "API do Dashboard rodando perfeitamente. Use a rota /api/login para autenticar."
    }), 200

@app.route('/api/login', methods=['POST'])
def login():
    dados = request.json
    usuario = dados.get('usuario')
    senha = dados.get('senha')

    print(f"Tentativa de login LDAP para: {usuario}")

    try:
        server = Server(LDAP_SERVER, get_info=ALL)

        # Monta o DN completo do usuário
        user_dn = f'cn={usuario},{OU_USERS},{BASE_DN}'
        print(f"DN utilizado: {user_dn}")

        # Tenta autenticar no LDAP
        conn = Connection(
            server,
            user=user_dn,
            password=senha,
            auto_bind=True
        )

        print("Login LDAP realizado com sucesso!")

        return jsonify({
            "status": "sucesso",
            "mensagem": "Acesso liberado pelo LDAP",
            "usuario": usuario,
            "token": "token-validado-pelo-ldap"
        }), 200

    except LDAPBindError:
        print("Usuário ou senha inválidos.")
        return jsonify({
            "status": "erro",
            "mensagem": "Usuário ou senha incorretos."
        }), 401

    except Exception as e:
        print(f"Erro ao conectar ao LDAP: {str(e)}")
        return jsonify({
            "status": "erro",
            "mensagem": f"Erro de conexão com o servidor LDAP: {str(e)}"
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
