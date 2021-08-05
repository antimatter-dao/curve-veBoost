# @version 0.2.15
"""
@title Voting Escrow Delegation
@author Curve Finance
@license MIT
"""


interface ERC721Receiver:
    def onERC721Received(
        _operator: address, _from: address, _token_id: uint256, _data: Bytes[4096]
    ) -> Bytes[4]:
        nonpayable


event Approval:
    _owner: indexed(address)
    _approved: indexed(address)
    _token_id: indexed(uint256)

event ApprovalForAll:
    _owner: indexed(address)
    _operator: indexed(address)
    _approved: bool

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _token_id: indexed(uint256)


balanceOf: public(HashMap[address, uint256])
getApproved: public(HashMap[uint256, address])
isApprovedForAll: public(HashMap[address, HashMap[address, bool]])
ownerOf: public(HashMap[uint256, address])


@internal
def _approve(_owner: address, _approved: address, _token_id: uint256):
    self.getApproved[_token_id] = _approved
    log Approval(_owner, _approved, _token_id)


@internal
def _transfer(_from: address, _to: address, _token_id: uint256):
    assert self.ownerOf[_token_id] == _from  # dev: _from is not owner
    assert _to != ZERO_ADDRESS  # dev: transfers to ZERO_ADDRESS are disallowed

    # clear previous token approval
    self._approve(_from, ZERO_ADDRESS, _token_id)

    self.balanceOf[_from] -= 1
    self.balanceOf[_to] += 1
    self.ownerOf[_token_id] = _to

    log Transfer(_from, _to, _token_id)


@view
@internal
def _is_approved_or_owner(_spender: address, _token_id: uint256) -> bool:
    owner: address = self.ownerOf[_token_id]
    return (
        _spender == owner
        or _spender == self.getApproved[_token_id]
        or self.isApprovedForAll[owner][_spender]
    )


@internal
def _burn(_token_id: uint256):
    owner: address = self.ownerOf[_token_id]

    self._approve(owner, ZERO_ADDRESS, _token_id)

    self.balanceOf[owner] -= 1
    self.ownerOf[_token_id] = ZERO_ADDRESS

    log Transfer(owner, ZERO_ADDRESS, _token_id)


@internal
def _mint(_to: address, _token_id: uint256):
    assert _to != ZERO_ADDRESS  # dev: minting to ZERO_ADDRESS disallowed
    assert self.ownerOf[_token_id] == ZERO_ADDRESS  # dev: token exists

    self.balanceOf[_to] += 1
    self.ownerOf[_token_id] = _to

    log Transfer(ZERO_ADDRESS, _to, _token_id)


@external
def approve(_approved: address, _token_id: uint256):
    """
    @notice Change or reaffirm the approved address for an NFT.
    @dev The zero address indicates there is no approved address.
        Throws unless `msg.sender` is the current NFT owner, or an authorized
        operator of the current owner.
    @param _approved The new approved NFT controller.
    @param _token_id The NFT to approve.
    """
    owner: address = self.ownerOf[_token_id]
    assert (
        msg.sender == owner or self.isApprovedForAll[owner][msg.sender]
    )  # dev: must be owner or operator
    self._approve(owner, _approved, _token_id)


@external
def safeTransferFrom(_from: address, _to: address, _token_id: uint256, _data: Bytes[4096] = b""):
    assert self._is_approved_or_owner(msg.sender, _token_id)
    self._transfer(_from, _to, _token_id)

    if _to.is_contract:
        response: Bytes[4] = ERC721Receiver(_to).onERC721Received(
            msg.sender, _from, _token_id, _data
        )
        assert response == method_id(
            "onERC721Received(address,address,uint256,bytes)"
        )  # dev: invalid response


@external
def setApprovalForAll(_operator: address, _approved: bool):
    """
    @notice Enable or disable approval for a third party ("operator") to manage
        all of `msg.sender`'s assets.
    @dev Emits the ApprovalForAll event. Multiple operators per account are allowed.
    @param _operator Address to add to the set of authorized operators.
    @param _approved True if the operator is approved, false to revoke approval.
    """
    self.isApprovedForAll[msg.sender][_operator] = _approved
    log ApprovalForAll(msg.sender, _operator, _approved)


@external
def transferFrom(_from: address, _to: address, _token_id: uint256):
    """
    @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
        TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
        THEY MAY BE PERMANENTLY LOST
    @dev Throws unless `msg.sender` is the current owner, an authorized
        operator, or the approved address for this NFT. Throws if `_from` is
        not the current owner. Throws if `_to` is the ZERO_ADDRESS.
    @param _from The current owner of the NFT
    @param _to The new owner
    @param _token_id The NFT to transfer
    """
    assert self._is_approved_or_owner(msg.sender, _token_id)
    self._transfer(_from, _to, _token_id)
