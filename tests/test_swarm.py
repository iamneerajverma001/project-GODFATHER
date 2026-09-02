import pytest
from neuroforge.swarm_protocol import SwarmAgent
import hashlib

def test_swarm_agent_crypto():
    """Test if Swarm Agent successfully derives a AES-256 root key from the physical PUF."""
    mock_puf_response = "01011100101010101110001"
    agent = SwarmAgent(puf_signature=mock_puf_response)
    
    # Assert public key is generated and is deterministic
    expected_key = hashlib.sha256(mock_puf_response.encode()).hexdigest()
    assert agent.public_key == expected_key

def test_swarm_agent_encryption():
    """Test the STDP blob encryption wrapper."""
    mock_puf_response = "TEST_PUF"
    agent = SwarmAgent(puf_signature=mock_puf_response)
    
    mock_weights = [0.1, -0.2, 0.05]
    payload = agent.encrypt_synaptic_weights(mock_weights)
    
    assert "origin_puf" in payload
    assert payload["origin_puf"] == agent.public_key
    assert "encrypted_tensor_bytes" in payload
