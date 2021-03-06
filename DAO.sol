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
Standard smart contract for a Decentralized Autonomous Organization (DAO)
to automate organizational governance and decision-making.
*/

import "./TokenCreation.sol";
import "./ManagedAccount.sol";


// Dao接口
//
// 任何人都可以将Ether发送到一个指定的钱包地址，以换取1-100的DAO Token.
// 任何有DAO Token的人都可以对投资计划进行投票。如果项目盈利，就会得到回报.
contract DAOInterface {

    // The amount of days for which people who try to participate in the
    // creation by calling the fallback function will still get their ether back
    //
    // 尝试通过调用fallback函数返回他们的 Ether 的天数 (锁定天数)
    uint constant creationGracePeriod = 40 days;


    // The minimum debate period that a generic proposal can have
    //
    // 通用提案可以拥有的最小辩论期 (犹豫期)
    uint constant minProposalDebatePeriod = 2 weeks;


    // The minimum debate period that a split proposal can have
    //
    // 拆分提案可以拥有的最小辩论期 (犹豫期)
    uint constant minSplitDebatePeriod = 1 weeks;


    // Period of days inside which it's possible to execute a DAO split
    //
    // 在几天之内可以执行DAO拆分 (每次拆分的间隔)
    uint constant splitExecutionPeriod = 27 days;


    // Period of time after which the minimum Quorum is halved
    //
    // 最小仲裁人数减半后的时间段 (间隔)
    uint constant quorumHalvingPeriod = 25 weeks;


    // Period after which a proposal is closed
    // (used in the case `executeProposal` fails because it throws)
    //
    // 提案关闭的期限
    // (在`executeProposal`因为抛出而失败的情况下使用)
    uint constant executeProposalPeriod = 10 days;


    // Denotes the maximum proposal deposit that can be given. It is given as
    // a fraction of total Ether spent plus balance of the DAO
    //
    // 表示可以提供的最大提案保证金。 它以 Ether 总支出的一部分 加上 DAO余额的形式给出
    uint constant maxDepositDivisor = 100;



    // Proposals to spend the DAO's ether or to choose a new Curator
    //
    // 花费DAO的 Ether 或 选择 负责人的 提案
    Proposal[] public proposals;


    // The quorum needed for each proposal is partially calculated by
    // totalSupply / minQuorumDivisor
    //
    // 每个提案所需的法定人数部分由totalSupply / minQuorumDivisor 计算
    uint public minQuorumDivisor;


    // The unix time of the last time quorum was reached on a proposal
    //
    // 提案已达到上次 法定的Unix时间
    uint  public lastTimeMinQuorumMet;

    // Address of the curator
    //
    // 负责人地址
    address public curator;


    // The whitelist: List of addresses the DAO is allowed to send ether to
    //
    // 白名单：允许DAO向其发送 Ether 的地址列表
    mapping (address => bool) public allowedRecipients;

    // Tracks the addresses that own Reward Tokens. Those addresses can only be
    // DAOs that have split from the original DAO. Conceptually, Reward Tokens
    // represent the proportion of the rewards that the DAO has the right to
    // receive. These Reward Tokens are generated when the DAO spends ether.
    //
    // 跟踪拥有奖励 token 的地址。 这些地址只能是与原始DAO分开的DAO。
    // 从概念上讲，奖励 token 代表DAO有权获得的奖励比例。 这些奖励 token 是在DAO花费 Ether 时生成的。
    mapping (address => uint) public rewardToken;


    // Total supply of rewardToken
    //
    // rewardToken的总供应量
    uint public totalRewardToken;

    // The account used to manage the rewards which are to be distributed to the
    // DAO Token Holders of this DAO
    //
    // 用于管理将分配给 该DAO的 `DAO Token` 持有人的奖励的帐户
    //
    // todo 账户管理 合约 实例
    ManagedAccount public rewardAccount;

    // The account used to manage the rewards which are to be distributed to
    // any DAO that holds Reward Tokens
    //
    // 用于管理奖励的帐户，该奖励将分发给持有奖励 token 的任何DAO
    //
    // todo 账户管理 合约 实例
    ManagedAccount public DAOrewardAccount;

    // Amount of rewards (in wei) already paid out to a certain DAO
    //
    // 已经支付给某个DAO的奖励金额（以wei为单位）
    mapping (address => uint) public DAOpaidOut;

    // Amount of rewards (in wei) already paid out to a certain address
    //
    // 已经支付到某个地址的奖励金额（以wei为单位）
    mapping (address => uint) public paidOut;

    // Map of addresses blocked during a vote (not allowed to transfer DAO
    // tokens). The address points to the proposal ID.
    //
    // 投票期间阻止的地址 Map（不允许转让DAO令牌）。 地址指向提案ID
    //
    // (address => proposalId)
    mapping (address => uint) public blocked;

    // The minimum deposit (in wei) required to submit any proposal that is not
    // requesting a new Curator (no deposit is required for splits)
    //
    // 提交任何不要求负责人的提案所需的最低保证金（以wei为单位）（拆分无需支付保证金）
    uint public proposalDeposit;

    // the accumulated sum of all current proposal deposits
    //
    // 所有当前 提案 质押的累计金额
    uint sumOfProposalDeposits;

    // Contract that is able to create a new DAO (with the same code as
    // this one), used for splits
    //
    // 能够创建一个新的DAO（使用与此相同的代码）的Dao工厂合约，用于拆分
    DAO_Creator public daoCreator;

    // A proposal with `newCurator == false` represents a transaction
    // to be issued by this DAO
    // A proposal with `newCurator == true` represents a DAO split
    //
    // 带有 `newCurator == false` 的提案表示将由该DAO发行的交易
    // 带有 `newCurator == true` 的提案表示DAO拆分
    struct Proposal {

        // The address where the `amount` will go to if the proposal is accepted
        // or if `newCurator` is true, the proposed Curator of
        // the new DAO).
        //
        // 如果提案被接受，或者如果 `newCurator` 为 true , 则 可以接收 amount 的 address。即 一个新Dao的提案负责人
        address recipient;

        // The amount to transfer to `recipient` if the proposal is accepted.
        //
        // 如果提案被接受，则转给 `recipient` 的金额  todo (wei ?)
        uint amount;

        // A plain text description of the proposal
        //
        // 提案的纯文本描述
        string description;

        // A unix timestamp, denoting the end of the voting period
        //
        // Unix时间戳，表示投票期的结束
        uint votingDeadline;

        // True if the proposal's votes have yet to be counted, otherwise False
        //
        // 如果尚未计算提案的票数，则为True，否则为False
        bool open;


        // True if quorum has been reached, the votes have been counted, and
        // the majority said yes
        //
        // 如果达到法定人数，已经计算票数，并且大多数人说 yes，则为真 todo 表示 提案 投票通过
        bool proposalPassed;


        // A hash to check validity of a proposal
        //
        // 检查提案有效性的 Hash值
        bytes32 proposalHash;

        // Deposit in wei the creator added when submitting their proposal. It
        // is taken from the msg.value of a newProposal call.
        //
        // 创建者 在提交提案时添加的押金。 它来自newProposal调用的msg.value
        uint proposalDeposit;

        // True if this proposal is to assign a new Curator
        //
        // 如果该提案分配新的 负责人，则为true
        bool newCurator;

        // Data needed for splitting the DAO
        //
        // 拆分DAO所需的数据
        SplitData[] splitData;

        // Number of Tokens in favor of the proposal
        //
        // 支持该提案的代币数量
        uint yea;

        // Number of Tokens opposed to the proposal
        //
        // 反对提案的代币数量
        uint nay;

        // Simple mapping to check if a shareholder has voted for it
        //
        // 简单 mapping 以检查 股东 是否投票赞成
        mapping (address => bool) votedYes;

        // Simple mapping to check if a shareholder has voted against it
        //
        // 简单 mapping 以检查 股东 是否投票反对
        mapping (address => bool) votedNo;

        // Address of the shareholder who created the proposal
        //
        // 创建提案的股东的地址
        address creator;
    }

    // Used only in the case of a newCurator proposal.
    //
    // 仅在 新负责人提案 的情况下使用。
    struct SplitData {

        // The balance of the current DAO minus the deposit at the time of split
        //
        // 当前DAO的余额 减去 拆分时的存款
        uint splitBalance;

        // The total amount of DAO Tokens in existence at the time of split.
        //
        // 拆分 时存在的 DAO Token 总数
        uint totalSupply;

        // Amount of Reward Tokens owned by the DAO at the time of split.
        //
        // 拆分 时DAO拥有的 奖励 Token 数量  todo (可能不是 Dao Token ??)
        uint rewardToken;

        // The new DAO contract created at the time of split.
        //
        // 拆分时创建的新DAO 合约实例
        DAO newDAO;
    }

    // Used to restrict access to certain functions to only DAO Token Holders
    //
    // 用于将访问权限限制为 仅 DAO Token 持有者 todo 需要被重写
    modifier onlyTokenholders {}

    /// @dev Constructor setting the Curator and the address
    /// for the contract able to create another DAO as well as the parameters
    /// for the DAO Token Creation
    /// @param _curator The Curator
    /// @param _daoCreator The contract able to (re)create this DAO
    /// @param _proposalDeposit The deposit to be paid for a regular proposal
    /// @param _minTokensToCreate Minimum required wei-equivalent tokens
    ///        to be created for a successful DAO Token Creation
    /// @param _closingTime Date (in Unix time) of the end of the DAO Token Creation
    /// @param _privateCreation If zero the DAO Token Creation is open to public, a
    /// non-zero address means that the DAO Token Creation is only for the address
    // This is the constructor: it can not be overloaded so it is commented out
    //  function DAO(
        //  address _curator,
        //  DAO_Creator _daoCreator,
        //  uint _proposalDeposit,
        //  uint _minTokensToCreate,
        //  uint _closingTime,
        //  address _privateCreation
    //  );


    /*
    @dev构造函数设置Curator和地址
    能够创建另一个DAO的合同以及参数
    用于DAO令牌创建
    @param _curator 负责人
    @param _daoCreator能够（重新）创建此DAO的合约
    @param _proposalDeposit定期投标要支付的保证金
    @param _minTokensToCreate成功创建DAO令牌需要创建的最小必需等效令牌
    @param _closingTime DAO令牌创建结束的日期（Unix时间）
    @param _privateCreation如果为零，则DAO令牌创建对公众开放，非零地址表示DAO令牌创建仅用于该地址
    这是构造函数：不能重载，因此已注释掉

    function DAO(
          address _curator,
          DAO_Creator _daoCreator,
          uint _proposalDeposit,
          uint _minTokensToCreate,
          uint _closingTime,
          address _privateCreation
    );

    */




    /// @notice Create Token with `msg.sender` as the beneficiary
    /// @return Whether the token creation was successful
    //
    // @notice以`msg.sender`作为受益人创建令牌
    // @return令牌创建是否成功
    function () returns (bool success);


    /// @dev This function is used to send ether back
    /// to the DAO, it can also be used to receive payments that should not be
    /// counted as rewards (donations, grants, etc.)
    /// @return Whether the DAO received the ether successfully
    //
    // @dev 此功能用于将以太币发送回DAO，也可以用于接收不应计为奖励的款项（捐赠，赠款等）
    // @return DAO是否成功接收到以太币
    function receiveEther() returns(bool);

    /// @notice `msg.sender` creates a proposal to send `_amount` Wei to
    /// `_recipient` with the transaction data `_transactionData`. If
    /// `_newCurator` is true, then this is a proposal that splits the
    /// DAO and sets `_recipient` as the new DAO's Curator.
    /// @param _recipient Address of the recipient of the proposed transaction
    /// @param _amount Amount of wei to be sent with the proposed transaction
    /// @param _description String describing the proposal
    /// @param _transactionData Data of the proposed transaction
    /// @param _debatingPeriod Time used for debating a proposal, at least 2
    /// weeks for a regular proposal, 10 days for new Curator proposal
    /// @param _newCurator Bool defining whether this proposal is about
    /// a new Curator or not
    /// @return The proposal ID. Needed for voting on the proposal
    //
    //
    // @notice  `msg.sender`创建一个提议，将带有交易数据`_transactionData`的_amount` Wei发送到`_recipient`.
    // 如果`_newCurator`为true，则这是一个拆分DAO并将“ _recipient`”设置为新DAO的Curator的提议.
    //
    // @param _recipient 提案交易的接收者的地址
    // @param _amount 与 提案交易 一起发送的wei的金额
    // @param _description 描述提案的字符串
    // @param _transactionData 提案交易的数据
    // @param _debatingPeriod 用于辩论提案的时间，对于常规提案，至少需要2周，对于新的负责人提案 (分裂出新的Dao)，至少需要10天
    // @param _newCurator 布尔定义此提案是否与新馆长有关
    //
    // @return 提案Id. 需要对该提案进行投票
    function newProposal(
        address _recipient,
        uint _amount,
        string _description,
        bytes _transactionData,
        uint _debatingPeriod,
        bool _newCurator
    ) onlyTokenholders returns (uint _proposalID);

    /// @notice Check that the proposal with the ID `_proposalID` matches the
    /// transaction which sends `_amount` with data `_transactionData`
    /// to `_recipient`
    /// @param _proposalID The proposal ID
    /// @param _recipient The recipient of the proposed transaction
    /// @param _amount The amount of wei to be sent in the proposed transaction
    /// @param _transactionData The data of the proposed transaction
    /// @return Whether the proposal ID matches the transaction data or not
    //
    // @notice 检查ID为 `_proposalID` 的提案是否与向 数据中 发送 `_transactionData` 的 `_amount` 到 `_recipient`的 tx匹配。
    //
    // @param _proposalID  提案ID
    // @param _recipient 提案交易的 接收人
    // @param _amount 提案交易中将发送的wei数量
    // @param _transactionData 提案交易的数据
    //
    // @return 提案ID 是否与 交易数据匹配
    function checkProposalCode(
        uint _proposalID,
        address _recipient,
        uint _amount,
        bytes _transactionData
    ) constant returns (bool _codeChecksOut);

    /// @notice Vote on proposal `_proposalID` with `_supportsProposal`
    /// @param _proposalID The proposal ID
    /// @param _supportsProposal Yes/No - support of the proposal
    /// @return The vote ID.
    //
    // @notice 对带有`_supportsProposal`的 提案 `_proposalID`进行投票
    //
    // @param _proposalID  提案ID
    // @param _supportsProposal  是/否 - 支持提案
    //
    // @return 投票ID
    function vote(
        uint _proposalID,
        bool _supportsProposal
    ) onlyTokenholders returns (uint _voteID);

    /// @notice Checks whether proposal `_proposalID` with transaction data
    /// `_transactionData` has been voted for or rejected, and executes the
    /// transaction in the case it has been voted for.
    /// @param _proposalID The proposal ID
    /// @param _transactionData The data of the proposed transaction
    /// @return Whether the proposed transaction has been executed or not
    //
    // @notice 检查具有交易数据`_transactionData`的提案 `_proposalID` 是否已被投票或拒绝，并在已被投票的情况下执行交易
    //
    // @param _proposalID 提案ID
    // @param _transactionData 提案交易的数据
    //
    // @return 提议的交易是否已经执行
    function executeProposal(
        uint _proposalID,
        bytes _transactionData
    ) returns (bool _success);

    /// @notice ATTENTION! I confirm to move my remaining ether to a new DAO
    /// with `_newCurator` as the new Curator, as has been
    /// proposed in proposal `_proposalID`. This will burn my tokens. This can
    /// not be undone and will split the DAO into two DAO's, with two
    /// different underlying tokens.
    /// @param _proposalID The proposal ID
    /// @param _newCurator The new Curator of the new DAO
    /// @dev This function, when called for the first time for this proposal,
    /// will create a new DAO and send the sender's portion of the remaining
    /// ether and Reward Tokens to the new DAO. It will also burn the DAO Tokens
    /// of the sender.
    //
    // todo 主要函数
    //
    /// @notice 注意！ 我确认将剩余的以太币 ether 移动到新的DAO中，
    ///         以_proposalID提案中的 提议 将新的_newCurator作为新的Curator。
    ///         这将烧毁我的 token。
    ///         无法撤消，它将DAO分为两个DAO，以及两个不同的基础token。
    ///
    /// @param _proposalID 提案ID
    /// @param _newCurator  新DAO的新负责人
    ///
    /// @dev 此函数在首次针对此 提议被调用时，将创建一个新的DAO，
    ///      并将剩余 ether 和 奖励token 的 sender部分发送给新的DAO。 它还将 burn sender 的DAO令牌。
    function splitDAO(
        uint _proposalID,
        address _newCurator
    ) returns (bool _success);

    /// @dev can only be called by the DAO itself through a proposal
    /// updates the contract of the DAO by sending all ether and rewardTokens
    /// to the new DAO. The new DAO needs to be approved by the Curator
    /// @param _newContract the address of the new contract
    //
    //
    /// @dev 只能由DAO本身通过提案来调用，该提案通过将所有 ether 和rewardToken发送给新DAO来更新DAO的合同。
    ///      新的DAO需要得到 负责人的批准.
    ///
    /// @param _newContract  新合约的地址
    function newContract(address _newContract);


    /// @notice Add a new possible recipient `_recipient` to the whitelist so
    /// that the DAO can send transactions to them (using proposals)
    /// @param _recipient New recipient address
    /// @dev Can only be called by the current Curator
    /// @return Whether successful or not
    //
    //
    /// @notice 在白名单中添加一个新的可能的接收者_recipient，以便DAO可以向他们发送交易（使用投标）
    ///
    /// @param _recipient 新 接收人地址
    ///
    /// @dev 只能由当前的Curator调用
    ///
    /// @return 是否成功
    function changeAllowedRecipients(address _recipient, bool _allowed) external returns (bool _success);


    /// @notice Change the minimum deposit required to submit a proposal
    /// @param _proposalDeposit The new proposal deposit
    /// @dev Can only be called by this DAO (through proposals with the
    /// recipient being this DAO itself)
    //
    //
    /// @notice 更改提交提案所需的最低存款
    ///
    /// @param _proposalDeposit 新提案存款
    ///
    /// @dev 只能由此DAO调用（通过提议，接收者是此DAO本身）
    function changeProposalDeposit(uint _proposalDeposit) external;

    /// @notice Move rewards from the DAORewards managed account
    /// @param _toMembers If true rewards are moved to the actual reward account
    ///                   for the DAO. If not then it's moved to the DAO itself
    /// @return Whether the call was successful
    //
    //
    /// @notice 从DAORewards管理帐户中转移奖励
    ///
    /// @param _toMembers 如果将真实的奖励转移到DAO的实际奖励帐户中.
    ///                   如果不是，则将其移至DAO本身.
    ///
    /// @return 调用是否成功
    function retrieveDAOReward(bool _toMembers) external returns (bool _success);

    /// @notice Get my portion of the reward that was sent to `rewardAccount`
    /// @return Whether the call was successful
    ///
    ///
    /// @notice 获取我已发送给`rewardAccount`的部分奖励
    ///
    /// @return 调用是否成功
    function getMyReward() returns(bool _success);

    /// @notice Withdraw `_account`'s portion of the reward from `rewardAccount`
    /// to `_account`'s balance
    /// @return Whether the call was successful
    ///
    ///
    /// @notice 将奖励的`_account`部分从`rewardAccount`中提取到`_account`的余额中
    ///
    /// @return 调用是否成功
    function withdrawRewardFor(address _account) internal returns (bool _success);

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`. Prior to this
    /// getMyReward() is called.
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transfered
    /// @return Whether the transfer was successful or not
    ///
    ///
    /// @notice 从`msg.sender`向`_to`发送`_amount` token。 在此之前，将调用getMyReward()
    ///
    /// @param _to 接收人的地址
    /// @param _amount 要转移的 token数量
    ///
    /// @return 传输是否成功
    function transferWithoutReward(address _to, uint256 _amount) returns (bool success);

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    /// is approved by `_from`. Prior to this getMyReward() is called.
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transfered
    /// @return Whether the transfer was successful or not
    ///
    ///
    /// @notice 在_from批准的情况下，将_amount token 从_from发送到_to。 在此之前，将调用getMyReward()
    ///
    /// @param _from 发送人的地址
    /// @param _to 接收人的地址
    /// @param _amount 要转移的 token数量
    ///
    /// @return 传输是否成功
    function transferFromWithoutReward(
        address _from,
        address _to,
        uint256 _amount
    ) returns (bool success);

    /// @notice Doubles the 'minQuorumDivisor' in the case quorum has not been
    /// achieved in 52 weeks
    /// @return Whether the change was successful or not
    ///
    ///
    /// @notice 如果在52周内未达到法定人数，则将'minQuorumDivisor'加倍
    ///
    /// @return 更改是否成功
    function halveMinQuorum() returns (bool _success);

    /// @return total number of proposals ever created
    ///
    /// @return 已创建的 提案总数
    function numberOfProposals() constant returns (uint _numberOfProposals);

    /// @param _proposalID Id of the new curator proposal
    /// @return Address of the new DAO
    ///
    ///
    /// @param _proposalID ID 新 负责人提议的Id
    ///
    /// @return新DAO的地址
    function getNewDAOAddress(uint _proposalID) constant returns (address _newDAO);

    /// @param _account The address of the account which is checked.
    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.
    ///
    /// @param _account 被检查的帐户的地址
    /// @return 帐户是否被阻止 (不允许转移 token)
    function isBlocked(address _account) internal returns (bool);

    /// @notice If the caller is blocked by a proposal whose voting deadline
    /// has exprired then unblock him.
    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.
    ///
    /// @notice 如果 调用者被投票截止时间已过的提案阻止，则取消阻止他。
    /// @return 帐户是否被阻止 (不允许转移令牌)
    function unblockMe() returns (bool);

    event ProposalAdded(
        uint indexed proposalID,
        address recipient,
        uint amount,
        bool newCurator,
        string description
    );
    event Voted(uint indexed proposalID, bool position, address indexed voter);
    event ProposalTallied(uint indexed proposalID, bool result, uint quorum);
    event NewCurator(address indexed _newCurator);
    event AllowedRecipientChanged(address indexed _recipient, bool _allowed);
}

//
// TODO  Dao 的玩法：
//
// todo DAO项目就可以开始利用融到的钱真正开始运作 (开始资金).
// todo 人们开始像DAO系统管理者提出如何使用这笔钱的方案，并且购买DAO的成员就有资格对这些提案进行投票.
//
// The DAO contract itself
contract DAO is DAOInterface, Token, TokenCreation {

    // Modifier that allows only shareholders to vote and create new proposals
    modifier onlyTokenholders {
        if (balanceOf(msg.sender) == 0) throw;
            _;
    }


    /*
    @dev构造函数设置Curator和地址
    能够创建另一个DAO的合同以及参数
    用于DAO令牌创建
    @param _curator 负责人
    @param _daoCreator 能够（重新）创建此DAO的合约
    @param _proposalDeposit 质押提案要支付的保证金
    @param _minTokensToCreate 成功创建DAO令牌需要创建的最小必需等效令牌
    @param _closingTime  DAO令牌创建结束的日期（Unix时间）
    @param _privateCreation 如果为零，则DAO令牌创建对公众开放，非零地址表示DAO令牌创建仅用于该地址


    */
    function DAO(
        address _curator,
        DAO_Creator _daoCreator,
        uint _proposalDeposit,
        uint _minTokensToCreate,
        uint _closingTime,
        address _privateCreation
    ) TokenCreation(_minTokensToCreate, _closingTime, _privateCreation) {

        // 设置 当前 Dao 的 负责人
        curator = _curator;
        // 设置能够（重新）创建此DAO的合约 (Dao 的工厂合约实例)
        daoCreator = _daoCreator;
        // 质押提案 要支付的保证金
        proposalDeposit = _proposalDeposit;

        // 设置 一个 Ether奖励 管理合约实例, 该合约的owner 是当前 Dao 合约, 且里面的奖励可以转给任何人
        rewardAccount = new ManagedAccount(address(this), false);
        // 再设置一个 Dao Token 奖励 管理合约实例, 该合约的owner 是当前 Dao 合约, 且里面的奖励可以转给任何人
        DAOrewardAccount = new ManagedAccount(address(this), false);

        //
        if (address(rewardAccount) == 0)
            throw;
        if (address(DAOrewardAccount) == 0)
            throw;

        // 设置当前时间为 `提案已达到上次 法定的Unix时间`
        lastTimeMinQuorumMet = now;

        // 将最小 法定 分母设置为20％
        minQuorumDivisor = 5; // sets the minimal quorum to 20%
        // 避免使用ID为0的提案，因为该提案已被使用
        proposals.length = 1; // avoids a proposal with ID 0 because it is used


        // 将当前 Dao 实例 加入白名单
        // todo 白名单：允许DAO向其发送 Ether 的地址列表
        allowedRecipients[address(this)] = true;

        // 将当前 Dao 的负责人地址 加入白名单
        allowedRecipients[curator] = true;
    }


    // TODO fallback() 函数
    function () returns (bool success) {


        if (now < closingTime + creationGracePeriod && msg.sender != address(extraBalance))
            return createTokenProxy(msg.sender);
        else
            return receiveEther();
    }


    // @dev 此功能用于将以太币发送回DAO，也可以用于接收不应计为奖励的款项（捐赠，赠款等）
    // @return DAO是否成功接收到以太币
    function receiveEther() returns (bool) {
        return true;
    }


    // @notice  `msg.sender`创建一个 提案，将带有交易数据`_transactionData`的_amount` Wei发送到`_recipient`.
    // 如果`_newCurator`为true，则这是一个拆分DAO并将“ _recipient`”设置为新DAO的Curator的提议.
    //
    // @param _recipient 提案交易的接收者的地址
    // @param _amount 与 提案交易 一起发送的wei的金额
    // @param _description 描述提案的字符串
    // @param _transactionData 提案交易的数据
    // @param _debatingPeriod 用于辩论提案的时间，对于常规提案，至少需要2周，对于新的负责人提案 (分裂出新的Dao)，至少需要10天
    // @param _newCurator 布尔定义此提案是否与新馆长有关
    //
    // @return 提案Id. 需要对该提案进行投票
    function newProposal(
        address _recipient,
        uint _amount,
        string _description,
        bytes _transactionData,
        uint _debatingPeriod,
        bool _newCurator
    ) onlyTokenholders returns (uint _proposalID) {

        // Sanity check
        // 完整性检查
        if (_newCurator && (
            _amount != 0
            || _transactionData.length != 0
            || _recipient == curator
            || msg.value > 0
            || _debatingPeriod < minSplitDebatePeriod)) {
            throw;
        } else if (
            !_newCurator
            && (!isRecipientAllowed(_recipient) || (_debatingPeriod <  minProposalDebatePeriod))
        ) {
            throw;
        }

        if (_debatingPeriod > 8 weeks)
            throw;

        if (!isFueled
            || now < closingTime
            || (msg.value < proposalDeposit && !_newCurator)) {

            throw;
        }

        // 防止溢出
        if (now + _debatingPeriod < now) // prevents overflow
            throw;

        // to prevent a 51% attacker to convert the ether into deposit
        // 防止51％的攻击者将 Ether 转换为存款
        if (msg.sender == address(this))
            throw;

        _proposalID = proposals.length++;
        Proposal p = proposals[_proposalID];
        p.recipient = _recipient;
        p.amount = _amount;
        p.description = _description;
        p.proposalHash = sha3(_recipient, _amount, _transactionData);
        p.votingDeadline = now + _debatingPeriod;
        p.open = true;
        //p.proposalPassed = False; // that's default
        // p.proposalPassed = False; //这是默认值
        p.newCurator = _newCurator;
        if (_newCurator)
            p.splitData.length++;
        p.creator = msg.sender;
        p.proposalDeposit = msg.value;

        sumOfProposalDeposits += msg.value;

        ProposalAdded(
            _proposalID,
            _recipient,
            _amount,
            _newCurator,
            _description
        );
    }


    // @notice 检查ID为 `_proposalID` 的提案是否与向 数据中 发送 `_transactionData` 的 `_amount` 到 `_recipient`的 tx匹配。
    //
    // @param _proposalID  提案ID
    // @param _recipient 提案交易的 接收人
    // @param _amount 提案交易中将发送的wei数量
    // @param _transactionData 提案交易的数据
    //
    // @return 提案ID 是否与 交易数据匹配
    function checkProposalCode(
        uint _proposalID,
        address _recipient,
        uint _amount,
        bytes _transactionData
    ) noEther constant returns (bool _codeChecksOut) {
        Proposal p = proposals[_proposalID];
        return p.proposalHash == sha3(_recipient, _amount, _transactionData);
    }


    // @notice 对带有`_supportsProposal`的 提案 `_proposalID`进行投票
    //
    // @param _proposalID  提案ID
    // @param _supportsProposal  是/否 - 支持提案
    //
    // @return 投票ID
    function vote(
        uint _proposalID,
        bool _supportsProposal
    ) onlyTokenholders noEther returns (uint _voteID) {

        Proposal p = proposals[_proposalID];
        if (p.votedYes[msg.sender]
            || p.votedNo[msg.sender]
            || now >= p.votingDeadline) {

            throw;
        }

        if (_supportsProposal) {
            p.yea += balances[msg.sender];
            p.votedYes[msg.sender] = true;
        } else {
            p.nay += balances[msg.sender];
            p.votedNo[msg.sender] = true;
        }

        if (blocked[msg.sender] == 0) {
            blocked[msg.sender] = _proposalID;
        } else if (p.votingDeadline > proposals[blocked[msg.sender]].votingDeadline) {
            // this proposal's voting deadline is further into the future than
            // the proposal that blocks the sender so make it the blocker
            blocked[msg.sender] = _proposalID;
        }

        Voted(_proposalID, _supportsProposal, msg.sender);
    }


    // @notice 检查具有交易数据`_transactionData`的提案 `_proposalID` 是否已被投票或拒绝，并在已被投票的情况下执行交易
    //
    // @param _proposalID 提案ID
    // @param _transactionData 提案交易的数据
    //
    // @return 提议的交易是否已经执行
    function executeProposal(
        uint _proposalID,
        bytes _transactionData
    ) noEther returns (bool _success) {

        Proposal p = proposals[_proposalID];

        uint waitPeriod = p.newCurator
            ? splitExecutionPeriod
            : executeProposalPeriod;
        // If we are over deadline and waiting period, assert proposal is closed
        if (p.open && now > p.votingDeadline + waitPeriod) {
            closeProposal(_proposalID);
            return;
        }

        // Check if the proposal can be executed
        if (now < p.votingDeadline  // has the voting deadline arrived?
            // Have the votes been counted?
            || !p.open
            // Does the transaction code match the proposal?
            || p.proposalHash != sha3(p.recipient, p.amount, _transactionData)) {

            throw;
        }

        // If the curator removed the recipient from the whitelist, close the proposal
        // in order to free the deposit and allow unblocking of voters
        if (!isRecipientAllowed(p.recipient)) {
            closeProposal(_proposalID);
            p.creator.send(p.proposalDeposit);
            return;
        }

        bool proposalCheck = true;

        if (p.amount > actualBalance())
            proposalCheck = false;

        uint quorum = p.yea + p.nay;

        // require 53% for calling newContract()
        if (_transactionData.length >= 4 && _transactionData[0] == 0x68
            && _transactionData[1] == 0x37 && _transactionData[2] == 0xff
            && _transactionData[3] == 0x1e
            && quorum < minQuorum(actualBalance() + rewardToken[address(this)])) {

                proposalCheck = false;
        }

        if (quorum >= minQuorum(p.amount)) {
            if (!p.creator.send(p.proposalDeposit))
                throw;

            lastTimeMinQuorumMet = now;
            // set the minQuorum to 20% again, in the case it has been reached
            if (quorum > totalSupply / 5)
                minQuorumDivisor = 5;
        }

        // Execute result
        if (quorum >= minQuorum(p.amount) && p.yea > p.nay && proposalCheck) {
            if (!p.recipient.call.value(p.amount)(_transactionData))
                throw;

            p.proposalPassed = true;
            _success = true;

            // only create reward tokens when ether is not sent to the DAO itself and
            // related addresses. Proxy addresses should be forbidden by the curator.
            if (p.recipient != address(this) && p.recipient != address(rewardAccount)
                && p.recipient != address(DAOrewardAccount)
                && p.recipient != address(extraBalance)
                && p.recipient != address(curator)) {

                rewardToken[address(this)] += p.amount;
                totalRewardToken += p.amount;
            }
        }

        closeProposal(_proposalID);

        // Initiate event
        ProposalTallied(_proposalID, _success, quorum);
    }


    function closeProposal(uint _proposalID) internal {
        Proposal p = proposals[_proposalID];
        if (p.open)
            sumOfProposalDeposits -= p.proposalDeposit;
        p.open = false;
    }

    //  todo TheDao出问题的代码 入口
    function splitDAO(
        uint _proposalID,
        address _newCurator
    ) noEther onlyTokenholders returns (bool _success) {

        Proposal p = proposals[_proposalID];

        // Sanity check

        if (now < p.votingDeadline  // has the voting deadline arrived?
            //The request for a split expires XX days after the voting deadline
            || now > p.votingDeadline + splitExecutionPeriod
            // Does the new Curator address match?
            || p.recipient != _newCurator
            // Is it a new curator proposal?
            || !p.newCurator
            // Have you voted for this split?
            || !p.votedYes[msg.sender]
            // Did you already vote on another proposal?
            || (blocked[msg.sender] != _proposalID && blocked[msg.sender] != 0) )  {

            throw;
        }

        // If the new DAO doesn't exist yet, create the new DAO and store the
        // current split data
        if (address(p.splitData[0].newDAO) == 0) {
            p.splitData[0].newDAO = createNewDAO(_newCurator);
            // Call depth limit reached, etc.
            if (address(p.splitData[0].newDAO) == 0)
                throw;
            // should never happen
            if (this.balance < sumOfProposalDeposits)
                throw;
            p.splitData[0].splitBalance = actualBalance();
            p.splitData[0].rewardToken = rewardToken[address(this)];
            p.splitData[0].totalSupply = totalSupply;
            p.proposalPassed = true;
        }

        //todo 攻击的 切入点
        // Move ether and assign new Tokens
        //
        // 源代码在TokenCreation.sol中，它会将代币从the parent DAO转移到the child DAO中
        uint fundsToBeMoved =
            (balances[msg.sender] * p.splitData[0].splitBalance) /
            p.splitData[0].totalSupply;  // 决定了要转移的代币数量  todo 并且p.splitData[0].totalSupply与balances[msg.sender]的值由于函数顺序问题没有被更新

        if (p.splitData[0].newDAO.createTokenProxy.value(fundsToBeMoved)(msg.sender) == false)
            throw;


        // Assign reward rights to new DAO
        uint rewardTokenToBeMoved =
            (balances[msg.sender] * p.splitData[0].rewardToken) /
            p.splitData[0].totalSupply;

        uint paidOutToBeMoved = DAOpaidOut[address(this)] * rewardTokenToBeMoved /
            rewardToken[address(this)];

        rewardToken[address(p.splitData[0].newDAO)] += rewardTokenToBeMoved;
        if (rewardToken[address(this)] < rewardTokenToBeMoved)
            throw;
        rewardToken[address(this)] -= rewardTokenToBeMoved;

        DAOpaidOut[address(p.splitData[0].newDAO)] += paidOutToBeMoved;
        if (DAOpaidOut[address(this)] < paidOutToBeMoved)
            throw;
        DAOpaidOut[address(this)] -= paidOutToBeMoved;

        // todo 攻击的切入点
        // Burn DAO Tokens
        //
        // 燃烧 Dao Token 换回 Ether
        Transfer(msg.sender, 0, balances[msg.sender]);
        withdrawRewardFor(msg.sender); // be nice, and get his rewards
        totalSupply -= balances[msg.sender];
        balances[msg.sender] = 0;
        paidOut[msg.sender] = 0;
        return true;
    }

    function newContract(address _newContract){
        if (msg.sender != address(this) || !allowedRecipients[_newContract]) return;
        // move all ether
        if (!_newContract.call.value(address(this).balance)()) {
            throw;
        }

        //move all reward tokens
        rewardToken[_newContract] += rewardToken[address(this)];
        rewardToken[address(this)] = 0;
        DAOpaidOut[_newContract] += DAOpaidOut[address(this)];
        DAOpaidOut[address(this)] = 0;
    }


    function retrieveDAOReward(bool _toMembers) external noEther returns (bool _success) {
        DAO dao = DAO(msg.sender);

        if ((rewardToken[msg.sender] * DAOrewardAccount.accumulatedInput()) /
            totalRewardToken < DAOpaidOut[msg.sender])
            throw;

        uint reward =
            (rewardToken[msg.sender] * DAOrewardAccount.accumulatedInput()) /
            totalRewardToken - DAOpaidOut[msg.sender];
        if(_toMembers) {
            if (!DAOrewardAccount.payOut(dao.rewardAccount(), reward))
                throw;
            }
        else {
            if (!DAOrewardAccount.payOut(dao, reward))
                throw;
        }
        DAOpaidOut[msg.sender] += reward;
        return true;
    }

    function getMyReward() noEther returns (bool _success) {
        return withdrawRewardFor(msg.sender);
    }

    // todo 攻击的 切入点
    function withdrawRewardFor(address _account) noEther internal returns (bool _success) {
        if ((balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply < paidOut[_account])
            throw;

        uint reward =
            (balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply - paidOut[_account];

        // todo 转款
        if (!rewardAccount.payOut(_account, reward))
            throw;

        // 这句 token 状态变更 不应该放在 `rewardAccount.payOut()` 之后的
        paidOut[_account] += reward;
        return true;
    }


    function transfer(address _to, uint256 _value) returns (bool success) {
        if (isFueled
            && now > closingTime
            && !isBlocked(msg.sender)
            && transferPaidOut(msg.sender, _to, _value)
            && super.transfer(_to, _value)) {

            return true;
        } else {
            throw;
        }
    }


    function transferWithoutReward(address _to, uint256 _value) returns (bool success) {
        if (!getMyReward())
            throw;
        return transfer(_to, _value);
    }


    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (isFueled
            && now > closingTime
            && !isBlocked(_from)
            && transferPaidOut(_from, _to, _value)
            && super.transferFrom(_from, _to, _value)) {

            return true;
        } else {
            throw;
        }
    }


    function transferFromWithoutReward(
        address _from,
        address _to,
        uint256 _value
    ) returns (bool success) {

        if (!withdrawRewardFor(_from))
            throw;
        return transferFrom(_from, _to, _value);
    }


    function transferPaidOut(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool success) {

        uint transferPaidOut = paidOut[_from] * _value / balanceOf(_from);
        if (transferPaidOut > paidOut[_from])
            throw;
        paidOut[_from] -= transferPaidOut;
        paidOut[_to] += transferPaidOut;
        return true;
    }


    function changeProposalDeposit(uint _proposalDeposit) noEther external {
        if (msg.sender != address(this) || _proposalDeposit > (actualBalance() + rewardToken[address(this)])
            / maxDepositDivisor) {

            throw;
        }
        proposalDeposit = _proposalDeposit;
    }


    function changeAllowedRecipients(address _recipient, bool _allowed) noEther external returns (bool _success) {
        if (msg.sender != curator)
            throw;
        allowedRecipients[_recipient] = _allowed;
        AllowedRecipientChanged(_recipient, _allowed);
        return true;
    }


    function isRecipientAllowed(address _recipient) internal returns (bool _isAllowed) {
        if (allowedRecipients[_recipient]
            || (_recipient == address(extraBalance)
                // only allowed when at least the amount held in the
                // extraBalance account has been spent from the DAO
                && totalRewardToken > extraBalance.accumulatedInput()))
            return true;
        else
            return false;
    }

    function actualBalance() constant returns (uint _actualBalance) {
        return this.balance - sumOfProposalDeposits;
    }


    function minQuorum(uint _value) internal constant returns (uint _minQuorum) {
        // minimum of 20% and maximum of 53.33%
        return totalSupply / minQuorumDivisor +
            (_value * totalSupply) / (3 * (actualBalance() + rewardToken[address(this)]));
    }


    function halveMinQuorum() returns (bool _success) {
        // this can only be called after `quorumHalvingPeriod` has passed or at anytime
        // by the curator with a delay of at least `minProposalDebatePeriod` between the calls
        if ((lastTimeMinQuorumMet < (now - quorumHalvingPeriod) || msg.sender == curator)
            && lastTimeMinQuorumMet < (now - minProposalDebatePeriod)) {
            lastTimeMinQuorumMet = now;
            minQuorumDivisor *= 2;
            return true;
        } else {
            return false;
        }
    }

    function createNewDAO(address _newCurator) internal returns (DAO _newDAO) {
        NewCurator(_newCurator);
        return daoCreator.createDAO(_newCurator, 0, 0, now + splitExecutionPeriod);
    }

    function numberOfProposals() constant returns (uint _numberOfProposals) {
        // Don't count index 0. It's used by isBlocked() and exists from start
        return proposals.length - 1;
    }

    function getNewDAOAddress(uint _proposalID) constant returns (address _newDAO) {
        return proposals[_proposalID].splitData[0].newDAO;
    }

    function isBlocked(address _account) internal returns (bool) {
        if (blocked[_account] == 0)
            return false;
        Proposal p = proposals[blocked[_account]];
        if (now > p.votingDeadline) {
            blocked[_account] = 0;
            return false;
        } else {
            return true;
        }
    }

    function unblockMe() returns (bool) {
        return isBlocked(msg.sender);
    }
}

contract DAO_Creator {
    function createDAO(
        address _curator,
        uint _proposalDeposit,
        uint _minTokensToCreate,
        uint _closingTime
    ) returns (DAO _newDAO) {

        return new DAO(
            _curator,
            DAO_Creator(this),
            _proposalDeposit,
            _minTokensToCreate,
            _closingTime,
            msg.sender
        );
    }
}
