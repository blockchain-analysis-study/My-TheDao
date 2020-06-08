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
 * Token Creation contract, used by the DAO to create its tokens and initialize
 * its ether. Feel free to modify the divisor method to implement different
 * Token Creation parameters
*/

// Token 创建 合约， todo 由DAO用于创建其 Token 并初始化其 Ether。 随时修改除数方法以实现不同的令牌创建参数

import "./Token.sol";
import "./ManagedAccount.sol";

contract TokenCreationInterface {

    // End of token creation, in Unix time
    //
    // 在Unix时间结束 Token 创建
    uint public closingTime;


    // Minimum fueling goal of the token creation, denominated in tokens to
    // be created
    //
    // Token 创建的最低 燃料目标，以要创建的 tokens 计价
    uint public minTokensToCreate;


    // True if the DAO reached its minimum fueling goal, false otherwise
    //
    // 如果 DAO 达到其最低 燃料目标，则为true，否则为false
    bool public isFueled;


    // For DAO splits - if privateCreation is 0, then it is a public token
    // creation, otherwise only the address stored in privateCreation is
    // allowed to create tokens
    //
    // 对于 DAO 拆分 -  如果 privateCreation 为0，则它是一个公共 Token 创建，否则仅允许存储在 privateCreation 中的地址创建 Token
    address public privateCreation;


    // hold extra ether which has been sent after the DAO token
    // creation rate has increased
    //
    // 保留在 DAO Token 创建速率提高后发送的额外 Ether todo 这是个 账户管理 合约实例
    ManagedAccount public extraBalance;


    // tracks the amount of wei given from each contributor (used for refund)
    //
    // 跟踪每个贡献者提供的wei金额（用于退款）
    mapping (address => uint256) weiGiven;

    /// @dev Constructor setting the minimum fueling goal and the
    /// end of the Token Creation
    /// @param _minTokensToCreate Minimum fueling goal in number of
    ///        Tokens to be created
    /// @param _closingTime Date (in Unix time) of the end of the Token Creation
    /// @param _privateCreation Zero means that the creation is public.  A
    /// non-zero address represents the only address that can create Tokens
    /// (the address can also create Tokens on behalf of other accounts)
    // This is the constructor: it can not be overloaded so it is commented out

    /// @dev构造函数设置最低加油目标并结束令牌创建
    ///
    /// @param _minTokensToCreate  要创建的Token 数量的最小加注目标
    /// @param _closingTime Token 创建结束的日期（Unix时间）
    /// @param _privateCreation 0表示创建是公共的。 非零地址表示唯一可以创建令牌的地址（该地址也可以代表其他帐户创建令牌）
    ///
    ///这是构造函数：不能重载，因此已注释掉

    //  function TokenCreation(
        //  uint _minTokensTocreate,
        //  uint _closingTime,
        //  address _privateCreation
    //  );




    /// @notice Create Token with `_tokenHolder` as the initial owner of the Token
    /// @param _tokenHolder The address of the Tokens's recipient
    /// @return Whether the token creation was successful
    ///
    /// @notice 使用`_tokenHolder`作为 Token 的初始所有者创建 Token
    ///
    /// @param _tokenHolder Token 接收者的地址
    /// @return Token 创建是否成功
    function createTokenProxy(address _tokenHolder) returns (bool success);

    /// @notice Refund `msg.sender` in the case the Token Creation did
    /// not reach its minimum fueling goal
    ///
    /// @ notice  退款`msg.sender`，以防 Token 创建未达到其最低加油目标
    function refund();

    /// @return The divisor used to calculate the token creation rate during
    /// the creation phase
    ///
    /// @return 在创建阶段用于计算 Token 创建率的除数
    function divisor() constant returns (uint divisor);

    event FuelingToDate(uint value);
    event CreatedToken(address indexed to, uint amount);
    event Refund(address indexed to, uint value);
}


// todo Token 创建 合约
contract TokenCreation is TokenCreationInterface, Token {

    /// @dev构造函数设置最低加油目标并结束令牌创建
    ///
    /// @param _minTokensToCreate  要创建的Token 数量的最小加注目标
    /// @param _closingTime Token 创建结束的日期（Unix时间）
    /// @param _privateCreation 0表示创建是公共的。 非零地址表示唯一可以创建令牌的地址（该地址也可以代表其他帐户创建令牌）
    ///
    function TokenCreation(
        uint _minTokensToCreate,
        uint _closingTime,
        address _privateCreation) {

        closingTime = _closingTime;
        minTokensToCreate = _minTokensToCreate;
        privateCreation = _privateCreation;

        // 保留在 DAO Token 创建速率提高后发送的额外 Ether todo 这是个 账户管理 合约实例
        extraBalance = new ManagedAccount(address(this), true);
    }


    /// @notice 使用`_tokenHolder`作为 Token 的初始所有者创建 Token
    ///
    /// @param _tokenHolder Token 接收者的地址
    /// @return Token 创建是否成功
    function createTokenProxy(address _tokenHolder) returns (bool success) {
        if (now < closingTime && msg.value > 0
            && (privateCreation == 0 || privateCreation == msg.sender)) {

            uint token = (msg.value * 20) / divisor();
            extraBalance.call.value(msg.value - token)();
            balances[_tokenHolder] += token;
            totalSupply += token;
            weiGiven[_tokenHolder] += msg.value;
            CreatedToken(_tokenHolder, token);
            if (totalSupply >= minTokensToCreate && !isFueled) {
                isFueled = true;
                FuelingToDate(totalSupply);
            }
            return true;
        }
        throw;
    }


    /// @ notice  退款`msg.sender`，以防 Token 创建未达到其最低加油目标
    function refund() noEther {
        if (now > closingTime && !isFueled) {
            // Get extraBalance - will only succeed when called for the first time
            //
            // 获得extraBalance-仅在首次调用时成功
            if (extraBalance.balance >= extraBalance.accumulatedInput())
                extraBalance.payOut(address(this), extraBalance.accumulatedInput());

            // Execute refund
            //
            // 执行退款
            if (msg.sender.call.value(weiGiven[msg.sender])()) {
                Refund(msg.sender, weiGiven[msg.sender]);
                totalSupply -= balances[msg.sender];
                balances[msg.sender] = 0;
                weiGiven[msg.sender] = 0;
            }
        }
    }


    /// @return 在创建阶段用于计算 Token 创建率的除数
    function divisor() constant returns (uint divisor) {
        // The number of (base unit) tokens per wei is calculated
        // as `msg.value` * 20 / `divisor`
        // The fueling period starts with a 1:1 ratio
        //
        // 每个wei（基本单位）令牌的数量计算为`msg.value` * 20 /`divisor`
        // 加油周期以1：1的比例开始
        if (closingTime - 2 weeks > now) {
            return 20;

        // Followed by 10 days with a daily creation rate increase of 5%
        //
        // 随后10天，每天的创建率增加5％
        } else if (closingTime - 4 days > now) {
            return (20 + (now - (closingTime - 2 weeks)) / (1 days));


        // The last 4 days there is a constant creation rate ratio of 1:1.5
        //
        // 最近4天的创建率恒定为1：1.5
        } else {
            return 30;
        }
    }
}
