from flask import Flask, request, jsonify
import snowflake.connector
import os
import logging
import json
from datetime import datetime

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

def get_snowflake_connection(user_token=None):
    """Create Snowflake connection with caller's rights if user token provided"""
    try:
        base_token = None
        with open('/snowflake/session/token', 'r') as f:
            base_token = f.read().strip()
        
        if user_token:
            # Use caller's rights with user token
            token = f"{base_token}.{user_token}"
            logging.info("Creating caller's rights connection")
        else:
            # Use service owner rights
            token = base_token
            logging.info("Creating owner's rights connection")
        
        conn = snowflake.connector.connect(
            host=os.getenv('SNOWFLAKE_HOST'),
            account=os.getenv('SNOWFLAKE_ACCOUNT'),
            token=token,
            authenticator='oauth',
            database=os.getenv('SNOWFLAKE_DATABASE'),
            schema=os.getenv('SNOWFLAKE_SCHEMA')
        )
        
        return conn
        
    except Exception as e:
        logging.error(f"Connection error: {str(e)}")
        raise

@app.route('/api/client-summary/<client_id>', methods=['GET'])
def get_client_summary(client_id):
    """Get transaction summary for specific client with caller's rights security"""
    try:
        # Get user token from header for caller's rights
        user_token = request.headers.get('Sf-Context-Current-User-Token')
        
        # Create connection with appropriate rights
        conn = get_snowflake_connection(user_token)
        cursor = conn.cursor()
        
        # Execute query - access controlled by caller grants and row policies
        query = """
        SELECT 
            client_id,
            COUNT(*) as transaction_count,
            SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_deposits,
            SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_withdrawals,
            MIN(transaction_date) as earliest_transaction,
            MAX(transaction_date) as latest_transaction
        FROM client_transactions 
        WHERE client_id = %s
        GROUP BY client_id
        """
        
        cursor.execute(query, (client_id,))
        result = cursor.fetchone()
        
        if result:
            return jsonify({
                'client_id': result[0],
                'transaction_count': result[1],
                'total_deposits': float(result[2]) if result[2] else 0,
                'total_withdrawals': float(result[3]) if result[3] else 0,
                'earliest_transaction': result[4].isoformat() if result[4] else None,
                'latest_transaction': result[5].isoformat() if result[5] else None,
                'access_method': 'caller_rights' if user_token else 'owner_rights',
                'timestamp': datetime.now().isoformat()
            })
        else:
            return jsonify({
                'error': 'No data found or access denied',
                'client_id': client_id,
                'access_method': 'caller_rights' if user_token else 'owner_rights'
            }), 403
            
    except Exception as e:
        logging.error(f"Error processing request for client {client_id}: {str(e)}")
        return jsonify({
            'error': str(e),
            'client_id': client_id,
            'access_method': 'caller_rights' if request.headers.get('Sf-Context-Current-User-Token') else 'owner_rights'
        }), 500
    finally:
        if 'conn' in locals():
            conn.close()

@app.route('/api/transactions/<client_id>', methods=['GET'])
def get_client_transactions(client_id):
    """Get detailed transactions for specific client"""
    try:
        user_token = request.headers.get('Sf-Context-Current-User-Token')
        conn = get_snowflake_connection(user_token)
        cursor = conn.cursor()
        
        # Get query parameters
        limit = request.args.get('limit', 100, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        query = """
        SELECT 
            transaction_id,
            account_id,
            amount,
            transaction_date,
            transaction_type
        FROM client_transactions 
        WHERE client_id = %s
        ORDER BY transaction_date DESC
        LIMIT %s OFFSET %s
        """
        
        cursor.execute(query, (client_id, limit, offset))
        results = cursor.fetchall()
        
        transactions = []
        for row in results:
            transactions.append({
                'transaction_id': row[0],
                'account_id': row[1],
                'amount': float(row[2]),
                'transaction_date': row[3].isoformat(),
                'transaction_type': row[4]
            })
        
        return jsonify({
            'client_id': client_id,
            'transactions': transactions,
            'count': len(transactions),
            'access_method': 'caller_rights' if user_token else 'owner_rights'
        })
        
    except Exception as e:
        logging.error(f"Error getting transactions for client {client_id}: {str(e)}")
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()

@app.route('/api/security-test', methods=['GET'])
def security_test():
    """Test endpoint to verify security configuration"""
    try:
        user_token = request.headers.get('Sf-Context-Current-User-Token')
        conn = get_snowflake_connection(user_token)
        cursor = conn.cursor()
        
        # Test query to see what data user can access
        cursor.execute("SELECT client_id, COUNT(*) FROM client_transactions GROUP BY client_id")
        results = cursor.fetchall()
        
        accessible_clients = []
        for row in results:
            accessible_clients.append({
                'client_id': row[0],
                'transaction_count': row[1]
            })
        
        return jsonify({
            'accessible_clients': accessible_clients,
            'access_method': 'caller_rights' if user_token else 'owner_rights',
            'current_user': 'masked_for_security',
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logging.error(f"Security test error: {str(e)}")
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'spcs-restricted-analytics',
        'version': '1.0',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/info', methods=['GET'])
def service_info():
    """Service information endpoint"""
    return jsonify({
        'service_name': 'SPCS Restricted Analytics Service',
        'version': '1.0',
        'description': 'Multi-tenant analytics service with caller\'s rights security',
        'capabilities': [
            'Caller\'s rights authentication',
            'Multi-tenant data isolation',
            'Real-time analytics',
            'Compliance-ready audit trails'
        ],
        'endpoints': [
            '/health - Health check',
            '/api/info - Service information',
            '/api/client-summary/<client_id> - Client transaction summary',
            '/api/transactions/<client_id> - Client transaction details',
            '/api/security-test - Security configuration test'
        ]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False) 