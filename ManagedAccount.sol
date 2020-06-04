/*
This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
Basic account, used by the DAO contract to separately manage both the rewards 
and the extraBalance accounts. 
*/
// 基本帐户，由DAO合同用来分别管理奖励帐户 和 extraBalance帐户
contract ManagedAccountInterface {


    // The only address with permission to withdraw from this account
    //
    // 唯一有权退出该帐户的地址
    address public owner;

    // If true, only the owner of the account can receive ether from it
    //
    // 如果为true，则只有帐户所有者可以从中接收 Ether
    bool public payOwnerOnly;

    // The sum of ether (in wei) which has been sent to this contract
    //
    // 已发送到此合同的 Ether （以wei为单位）
    uint public accumulatedInput;

    /// @notice Sends `_amount` of wei to _recipient
    /// @param _amount The amount of wei to send to `_recipient`
    /// @param _recipient The address to receive `_amount` of wei
    /// @return True if the send completed
    //
    // todo  将wei的_amount发送给_recipient
    // @param _amount 发送到`_recipient`的wei的数量
    // @param _recipient  接收wei的_amount的地址
    // @return 如果发送完成则为True
    function payOut(address _recipient, uint _amount) returns (bool);

    event PayOut(address indexed _recipient, uint _amount);
}

// 账户管理 合约
contract ManagedAccount is ManagedAccountInterface{

    // The constructor sets the owner of the account
    //
    // 构造函数. 设置合约的 owner, 和是否只有 owner 可以接收 Ether
    function ManagedAccount(address _owner, bool _payOwnerOnly) {
        owner = _owner;
        payOwnerOnly = _payOwnerOnly;
    }

    // When the contract receives a transaction without data this is called. 
    // It counts the amount of ether it receives and stores it in 
    // accumulatedInput.
    //
    // todo fallback 函数
    //
    // todo 向当前合约转账时 触发
    // todo 调用当前合约不存在的func时 触发
    //
    // 当合同接收到没有数据的交易时，这称为。
    // 它计算接收到的以太量，并将其存储在累计输入中。
    function() {

        // 累计 转到当前 合约的 Ether
        accumulatedInput += msg.value;
    }

    // todo 将 amount 数目的 Ether 转到 _recipient  （只有当前 owner 才可以操作的 合约）
    function payOut(address _recipient, uint _amount) returns (bool) {

        // 如果当前 sender 不是owner
        // 或者 当前 msg.value > 0即向当前合约转账时
        // 或者 (只有当前合约的owner可以接收当前合约中的Ether  且  _recipient 不是当前 owner时)
        if (msg.sender != owner || msg.value > 0 || (payOwnerOnly && _recipient != owner))
            throw;

        // 给当前 _recipient 转 amount 的 Ether
        //
        // todo 对_recipient发出 call() 调用，转账_amount个Wei，call() 调用默认会使用当前剩余的所有gas (fallback函数花)
        if (_recipient.call.value(_amount)()) { // todo 注意这一行,  TheDao 攻击事件的 切入点
            /// 记 Event
            PayOut(_recipient, _amount);
            return true;
        } else {
            return false;
        }
    }
}
