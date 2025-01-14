// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import "@eth-optimism-bedrock/contracts/libraries/Predeploys.sol";
import "@eth-optimism-bedrock/contracts/universal/ProxyAdmin.sol";
import "@eth-optimism-bedrock/contracts/legacy/AddressManager.sol";
import "@eth-optimism-bedrock/contracts/legacy/L1ChugSplashProxy.sol";
import "@eth-optimism-bedrock/contracts/universal/Proxy.sol";
import "@eth-optimism-bedrock/contracts/legacy/ResolvedDelegateProxy.sol";

import "@eth-optimism-bedrock/contracts/L1/L1CrossDomainMessenger.sol";
import "@eth-optimism-bedrock/contracts/L1/L1StandardBridge.sol";
import "@eth-optimism-bedrock/contracts/L1/L2OutputOracle.sol";
import "@eth-optimism-bedrock/contracts/L1/OptimismPortal.sol";
import "@eth-optimism-bedrock/contracts/L1/ResourceMetering.sol";
import "@eth-optimism-bedrock/contracts/universal/OptimismMintableERC20Factory.sol";
import "@eth-optimism-bedrock/contracts/L1/L1ERC721Bridge.sol";

import "@eth-optimism-bedrock/contracts/deployment/PortalSender.sol";
import "@eth-optimism-bedrock/contracts/L1/SystemConfig.sol";
import "@eth-optimism-bedrock/contracts/deployment/SystemDictator.sol";

import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "script/deploy/Utils.sol";

contract DeployBedrock is Script {
    using stdJson for string;

    Utils utils;
    address deployer;
    Utils.DeployBedrockConfig deployConfig;
    SystemDictator.DeployConfig systemDictatorDeployConfig;
    bytes32 batcherHash;

    // System contracts
    ProxyAdmin proxyAdmin;
    AddressManager addressManager;

    // L1ChugSplash proxies
    L1ChugSplashProxy l1StandardBridgeProxy;

    // Proxy proxies
    Proxy l2OutputOracleProxy;
    Proxy optimismPortalProxy;
    Proxy optimismMintableERC20FactoryProxy;
    Proxy l1ERC721BridgeProxy;
    Proxy systemConfigProxy;
    Proxy systemDictatorProxy;

    // ResolvedDelegate proxies
    ResolvedDelegateProxy l1CrossDomainMessengerProxy;

    // Implementations
    L1CrossDomainMessenger l1CrossDomainMessengerImpl;
    L1StandardBridge l1StandardBridgeImpl;
    L2OutputOracle l2OutputOracleImpl;
    OptimismPortal optimismPortalImpl;
    OptimismMintableERC20Factory optimismMintableERC20FactoryImpl;
    L1ERC721Bridge l1ERC721BridgeImpl;
    PortalSender portalSenderImpl;
    SystemConfig systemConfigImpl;
    SystemDictator systemDictatorImpl;

    function run() public {
        utils = new Utils();
        deployConfig = utils.getDeployBedrockConfig();
        deployer = deployConfig.deployerAddress;
        batcherHash = bytes32(abi.encode(deployConfig.batchSenderAddress));

        // 000-ProxyAdmin.ts
        vm.broadcast(deployer);
        proxyAdmin = new ProxyAdmin(deployer);
        require(proxyAdmin.owner() == deployer, "Deploy: proxyAdmin owner is incorrect");

        // 001-AddressManager.ts
        vm.broadcast(deployer);
        addressManager = new AddressManager();
        require(addressManager.owner() == deployer, "Deploy: addressManager owner is incorrect");
        
        // 002-L1StandardBridgeProxy.ts
        vm.broadcast(deployer);
        l1StandardBridgeProxy = new L1ChugSplashProxy(deployer);
        vm.prank(address(0));
        require(l1StandardBridgeProxy.getOwner() == deployer, "Deploy: l1ChugSplashProxy owner is incorrect");

        // 003-L2OutputOracleProxy.ts
        vm.broadcast(deployer);
        l2OutputOracleProxy = new Proxy(address(proxyAdmin));
        vm.prank(address(0));
        require(l2OutputOracleProxy.admin() == address(proxyAdmin), "Deploy: l2OutputOracleProxy admin is incorrect");

        // 004-L1CrossDomainMessengerProxy.ts
        string memory implementationName = 'OVM_L1CrossDomainMessenger';
        vm.broadcast(deployer);
        l1CrossDomainMessengerProxy = new ResolvedDelegateProxy(addressManager, implementationName);

        // 005-OptimismPortalProxy.ts
        vm.broadcast(deployer);
        optimismPortalProxy = new Proxy(address(proxyAdmin));
        vm.prank(address(0));
        require(optimismPortalProxy.admin() == address(proxyAdmin), "Deploy: optimismPortalProxy admin is incorrect");

        // 006-OptimismMintableERC20FactoryProxy.ts
        vm.broadcast(deployer);
        optimismMintableERC20FactoryProxy =  new Proxy(address(proxyAdmin));
        vm.prank(address(0));
        require(optimismMintableERC20FactoryProxy.admin() == address(proxyAdmin), "Deploy: optimismMintableERC20FactoryProxy admin is incorrect");

        // 007-L1ERC721BridgeProxy.ts
        vm.broadcast(deployer);
        l1ERC721BridgeProxy =  new Proxy(deployer);
        vm.prank(address(0));
        require(l1ERC721BridgeProxy.admin() == deployer, "Deploy: l1ERC721BridgeProxy admin is incorrect");

        // 008-SystemConfigProxy.ts
        vm.broadcast(deployer);
        systemConfigProxy =  new Proxy(address(proxyAdmin));
        vm.prank(address(0));
        require(systemConfigProxy.admin() == address(proxyAdmin), "Deploy: systemConfigProxy admin is incorrect");

        // 009-SystemDictatorProxy.ts
        vm.broadcast(deployer);
        systemDictatorProxy =  new Proxy(deployer);
        vm.prank(address(0));
        require(systemDictatorProxy.admin() == deployer, "Deploy: systemDictatorProxy admin is incorrect");

        // 010-L1CrossDomainMessengerImpl.ts
        vm.broadcast(deployer);
        l1CrossDomainMessengerImpl = new L1CrossDomainMessenger(OptimismPortal(payable(address(optimismPortalProxy))));
        vm.prank(address(0));
        require(address(l1CrossDomainMessengerImpl.PORTAL()) == address(optimismPortalProxy), "Deploy: l1CrossDomainMessenger portal proxy is incorrect");

        // 011-L1StandardBridgeImpl.ts
        vm.broadcast(deployer);
        l1StandardBridgeImpl = new L1StandardBridge(payable(address(l1CrossDomainMessengerProxy)));
        require(address(l1StandardBridgeImpl.MESSENGER()) == address(l1CrossDomainMessengerProxy), "Deploy: l1StandardBridge l1 cross domain messenger proxy is incorrect");
        require(address(l1StandardBridgeImpl.OTHER_BRIDGE()) == Predeploys.L2_STANDARD_BRIDGE, "Deploy: l1StandardBridge other bridge is incorrect");

        // 012-L2OutputOracleImpl.ts
        vm.broadcast(deployer);
        l2OutputOracleImpl = new L2OutputOracle(
            deployConfig.l2OutputOracleSubmissionInterval,
            deployConfig.l2BlockTime,
            0,
            0,
            deployConfig.l2OutputOracleProposer,
            deployConfig.l2OutputOracleChallenger,
            deployConfig.finalizationPeriodSeconds
        );
        require(l2OutputOracleImpl.SUBMISSION_INTERVAL() == deployConfig.l2OutputOracleSubmissionInterval, "Deploy: l2OutputOracle submissionInterval is incorrect");
        require(l2OutputOracleImpl.L2_BLOCK_TIME() == deployConfig.l2BlockTime, "Deploy: l2OutputOracle l2BlockTime is incorrect");
        require(l2OutputOracleImpl.startingBlockNumber() == 0, "Deploy: l2OutputOracle startingBlockNumber is incorrect");
        require(l2OutputOracleImpl.startingTimestamp() == 0, "Deploy: l2OutputOracle startingTimestamp is incorrect");
        require(l2OutputOracleImpl.PROPOSER() == deployConfig.l2OutputOracleProposer, "Deploy: l2OutputOracle proposer is incorrect");
        require(l2OutputOracleImpl.CHALLENGER() == deployConfig.l2OutputOracleChallenger, "Deploy: l2OutputOracle challenger is incorrect");
        require(l2OutputOracleImpl.FINALIZATION_PERIOD_SECONDS() == deployConfig.finalizationPeriodSeconds, "Deploy: l2OutputOracle finalizationPeriodSeconds is incorrect");

        // 013-OptimismPortalImpl.ts
        vm.broadcast(deployer);
        optimismPortalImpl = new OptimismPortal(
            L2OutputOracle(address(l2OutputOracleProxy)),
            deployConfig.portalGuardian,
            true,
            SystemConfig(address(systemConfigProxy))
        );
        require(address(optimismPortalImpl.L2_ORACLE()) == address(l2OutputOracleProxy), "Deploy: optimismPortal l2OutputOracle proxy is incorrect");
        require(optimismPortalImpl.GUARDIAN() == deployConfig.portalGuardian, "Deploy: optimismPortal GUARDIAN is incorrect");
        require(optimismPortalImpl.paused() == true, "Deploy: optimismPortal pause state is incorrect");
        require(address(optimismPortalImpl.SYSTEM_CONFIG()) == address(systemConfigProxy), "Deploy: optimismPortal SystemConfig is incorrect");

        // 014-OptimismMintableERC20FactoryImpl.ts
        vm.broadcast(deployer);
        optimismMintableERC20FactoryImpl = new OptimismMintableERC20Factory(address(l1StandardBridgeProxy));
        require(optimismMintableERC20FactoryImpl.BRIDGE() == address(l1StandardBridgeProxy), "Deploy: optimismMintableERC20Factory l1StandardBridgeProxy is incorrect");

        // 015-L1ERC721BridgeImpl.ts
        vm.broadcast(deployer);
        l1ERC721BridgeImpl = new L1ERC721Bridge(address(l1CrossDomainMessengerProxy), Predeploys.L2_ERC721_BRIDGE);
        require(address(l1ERC721BridgeImpl.MESSENGER()) == address(l1CrossDomainMessengerProxy), "Deploy: l1ERC721Bridge l1CrossDomainMessengerProxy is incorrect");
        require(l1ERC721BridgeImpl.OTHER_BRIDGE() == Predeploys.L2_ERC721_BRIDGE, "Deploy: l1ERC721Bridge l2ERC721Briddge is incorrect");

        // 016-PortalSenderImpl.ts
        vm.broadcast(deployer);
        portalSenderImpl = new PortalSender(OptimismPortal(payable(address(optimismPortalProxy))));
        require(address(portalSenderImpl.PORTAL()) == address(optimismPortalProxy), "Deploy: portalSender optimismPortalProxy is incorrect");

        // 017-SystemConfigImpl.ts
        ResourceMetering.ResourceConfig memory defaultResourceCfg = Constants.DEFAULT_RESOURCE_CONFIG();
        vm.broadcast(deployer);
        systemConfigImpl = new SystemConfig(
            deployConfig.finalSystemOwner,
            deployConfig.gasPriceOracleOverhead,
            deployConfig.gasPriceOracleScalar,
            batcherHash,
            deployConfig.l2GenesisBlockGasLimit,
            deployConfig.p2pSequencerAddress,
            defaultResourceCfg
        );
        require(deployConfig.l2GenesisBlockGasLimit >= defaultResourceCfg.systemTxMaxGas + defaultResourceCfg.maxResourceLimit, "Deploy: l2GenesisBlockGasLimit too low");
        require(address(systemConfigImpl.owner()) == deployConfig.finalSystemOwner, "Deploy: systemConfig finalSystemOwner is incorrect");
        require(systemConfigImpl.overhead() == deployConfig.gasPriceOracleOverhead, "Deploy: systemConfig gasPriceOracleOverhead is incorrect");
        require(systemConfigImpl.scalar() == deployConfig.gasPriceOracleScalar, "Deploy: systemConfig gasPriceOracleScalar is incorrect");
        require(systemConfigImpl.batcherHash() == batcherHash, "Deploy: systemConfig batcherHash is incorrect");
        require(systemConfigImpl.gasLimit() == deployConfig.l2GenesisBlockGasLimit, "Deploy: systemConfig l2GenesisBlockGasLimit is incorrect");
        require(systemConfigImpl.unsafeBlockSigner() == deployConfig.p2pSequencerAddress, "Deploy: systemConfig p2pSequencerAddress is incorrect");
        require(keccak256(abi.encode(systemConfigImpl.resourceConfig())) == keccak256(abi.encode(defaultResourceCfg)), "Deploy: systemConfig resourceConfig is incorrect");

        // 018-SystemDictatorImpl.ts
        vm.broadcast(deployer);
        systemDictatorImpl = new SystemDictator();

        // 019-SystemDictatorInit.ts
        systemDictatorInit();

        // 020-SystemDictatorSteps.ts
        systemDictatorSteps();


        Utils.AddressesConfig memory finalCfg;

        // Proxy contract addresses
        finalCfg.ProxyAdmin = address(proxyAdmin);
        finalCfg.AddressManager = address(addressManager);
        finalCfg.L1StandardBridgeProxy = address(l1StandardBridgeProxy);
        finalCfg.L2OutputOracleProxy = address(l2OutputOracleProxy);
        finalCfg.L1CrossDomainMessengerProxy = address(l1CrossDomainMessengerProxy);
        finalCfg.OptimismPortalProxy = address(optimismPortalProxy);
        finalCfg.OptimismMintableERC20FactoryProxy = address(optimismMintableERC20FactoryProxy);
        finalCfg.L1ERC721BridgeProxy = address(l1ERC721BridgeProxy);
        finalCfg.SystemConfigProxy = address(systemConfigProxy);
        finalCfg.SystemDictatorProxy = address(systemDictatorProxy);

        utils.writeAddressesFile(finalCfg);
    }
    
    function systemDictatorInit() internal {
        console.log("Setting up SystemDictator global configuration");
        SystemDictator.GlobalConfig storage globalConfig = systemDictatorDeployConfig.globalConfig;
        globalConfig.addressManager = addressManager;
        globalConfig.proxyAdmin = proxyAdmin;
        globalConfig.finalOwner = deployConfig.finalSystemOwner;
        globalConfig.controller = deployConfig.controller;

        console.log("Setting up SystemDictator proxy address configuration");
        SystemDictator.ProxyAddressConfig storage proxyAddressConfig = systemDictatorDeployConfig.proxyAddressConfig;
        proxyAddressConfig.l2OutputOracleProxy = address(l2OutputOracleProxy);
        proxyAddressConfig.optimismPortalProxy = address(optimismPortalProxy);
        proxyAddressConfig.l1CrossDomainMessengerProxy = address(l1CrossDomainMessengerProxy);
        proxyAddressConfig.l1StandardBridgeProxy = address(l1StandardBridgeProxy);
        proxyAddressConfig.optimismMintableERC20FactoryProxy = address(optimismMintableERC20FactoryProxy);
        proxyAddressConfig.l1ERC721BridgeProxy = address(l1ERC721BridgeProxy);
        proxyAddressConfig.systemConfigProxy = address(systemConfigProxy);

        console.log("Setting up SystemDictator implementation address configuration");
        SystemDictator.ImplementationAddressConfig storage implementationAddressConfig = systemDictatorDeployConfig.implementationAddressConfig;
        implementationAddressConfig.l2OutputOracleImpl = l2OutputOracleImpl;
        implementationAddressConfig.optimismPortalImpl = optimismPortalImpl;
        implementationAddressConfig.l1CrossDomainMessengerImpl = l1CrossDomainMessengerImpl;
        implementationAddressConfig.l1StandardBridgeImpl = l1StandardBridgeImpl;
        implementationAddressConfig.optimismMintableERC20FactoryImpl = optimismMintableERC20FactoryImpl;
        implementationAddressConfig.l1ERC721BridgeImpl = l1ERC721BridgeImpl;
        implementationAddressConfig.portalSenderImpl = portalSenderImpl;
        implementationAddressConfig.systemConfigImpl = systemConfigImpl;

        console.log("Setting up SystemDictator system config configuration");
        SystemDictator.SystemConfigConfig storage systemConfigConfig = systemDictatorDeployConfig.systemConfigConfig;
        systemConfigConfig.owner = deployConfig.finalSystemOwner;
        systemConfigConfig.overhead = deployConfig.gasPriceOracleOverhead;
        systemConfigConfig.scalar = deployConfig.gasPriceOracleScalar;
        systemConfigConfig.batcherHash = batcherHash;
        systemConfigConfig.gasLimit = deployConfig.l2GenesisBlockGasLimit;
        systemConfigConfig.unsafeBlockSigner = deployConfig.p2pSequencerAddress;
        systemConfigConfig.resourceConfig = Constants.DEFAULT_RESOURCE_CONFIG();

        vm.broadcast(deployer);
        systemDictatorProxy.upgradeToAndCall(
            address(systemDictatorImpl),
            bytes.concat(SystemDictator.initialize.selector, abi.encode(systemDictatorDeployConfig))
        );        
        
        SystemDictator.DeployConfig memory actualConfig;
        (actualConfig.globalConfig, actualConfig.proxyAddressConfig, actualConfig.implementationAddressConfig, actualConfig.systemConfigConfig)= SystemDictator(address(systemDictatorProxy)).config();
        require(keccak256(abi.encode(actualConfig)) == keccak256(abi.encode(systemDictatorDeployConfig)), "Deploy: unexpected systemDictator configuration found");
    }

    function systemDictatorSteps() internal {
        vm.broadcast(deployer);
        OwnableUpgradeable(address(proxyAdmin)).transferOwnership(address(systemDictatorProxy));
        require(proxyAdmin.owner() == address(systemDictatorProxy), "Deploy: proxyAdmin owner is incorrect");
        vm.broadcast(deployer);
        OwnableUpgradeable(address(addressManager)).transferOwnership(address(systemDictatorProxy));
        require(addressManager.owner() == address(systemDictatorProxy), "Deploy: addressManager owner is incorrect");
        vm.broadcast(deployer);
        L1ChugSplashProxy(payable(address(l1StandardBridgeProxy))).setOwner(address(systemDictatorProxy));
        vm.prank(address(0));
        require(l1StandardBridgeProxy.getOwner() == address(systemDictatorProxy), "Deploy: l1StandardBridgeProxy owner is incorrect");
        vm.broadcast(deployer);
        Proxy(payable(address(l1ERC721BridgeProxy))).changeAdmin(address(systemDictatorProxy));
        vm.prank(address(0));
        require(l1ERC721BridgeProxy.admin() == address(systemDictatorProxy), "Deploy: l1ERC721BridgeProxy admin is incorrect");

        SystemDictator systemDictator = SystemDictator(address(systemDictatorProxy));
        vm.broadcast(deployer);
        systemDictator.step1();

        require(proxyAdmin.addressManager() == addressManager, "Deploy: proxyAdmin address manager is incorrect");
        require(keccak256(abi.encode(proxyAdmin.implementationName(address(l1CrossDomainMessengerProxy)))) == keccak256(abi.encode("OVM_L1CrossDomainMessenger")), "Deploy: proxyAdmin l1CrossDomainMessengerProxy implementation name is incorrect");
        require(proxyAdmin.proxyType(address(l1CrossDomainMessengerProxy)) == ProxyAdmin.ProxyType.RESOLVED, "Deploy: proxyAdmin l1CrossDomainMessengerProxy proxy type is incorrect");
        require(proxyAdmin.proxyType(address(l1StandardBridgeProxy)) == ProxyAdmin.ProxyType.CHUGSPLASH, "Deploy: proxyAdmin l1StandardBridgeProxy proxy type is incorrect");
        
        SystemConfig testingSystemConfigProxy = SystemConfig(address(systemConfigProxy));
        require(address(testingSystemConfigProxy.owner()) == deployConfig.finalSystemOwner, "Deploy: systemConfig proxy finalSystemOwner is incorrect");
        require(testingSystemConfigProxy.overhead() == deployConfig.gasPriceOracleOverhead, "Deploy: systemConfig proxy gasPriceOracleOverhead is incorrect");
        require(testingSystemConfigProxy.scalar() == deployConfig.gasPriceOracleScalar, "Deploy: systemConfig proxy gasPriceOracleScalar is incorrect");
        require(testingSystemConfigProxy.batcherHash() == batcherHash, "Deploy: systemConfig proxy batcherHash is incorrect");
        require(testingSystemConfigProxy.gasLimit() == deployConfig.l2GenesisBlockGasLimit, "Deploy: systemConfig proxy l2GenesisBlockGasLimit is incorrect");
        require(testingSystemConfigProxy.unsafeBlockSigner() == deployConfig.p2pSequencerAddress, "Deploy: systemConfig proxy p2pSequencerAddress is incorrect");
        
        ResourceMetering.ResourceConfig memory defaultResourceCfg = Constants.DEFAULT_RESOURCE_CONFIG();
        ResourceMetering.ResourceConfig memory testResourceConfig = testingSystemConfigProxy.resourceConfig();
        require(keccak256(abi.encode(testResourceConfig)) == keccak256(abi.encode(defaultResourceCfg)), "Deploy: systemConfig resourceConfig is incorrect");
        require(testResourceConfig.maxResourceLimit == 20_000_000, "Deploy maxResourceLimit is incorrect");
        require(testResourceConfig.elasticityMultiplier == 10, "Deploy elasticityMultiplier is incorrect");
        require(testResourceConfig.baseFeeMaxChangeDenominator == 8, "Deploy baseFeeMaxChangeDenominator is incorrect");
        require(testResourceConfig.minimumBaseFee == 1 gwei, "Deploy minimumBaseFee is incorrect");
        require(testResourceConfig.systemTxMaxGas == 1_000_000, "Deploy systemTxMaxGas is incorrect");
        require(testResourceConfig.maximumBaseFee == type(uint128).max, "Deploy maximumBaseFee is incorrect");

        require(addressManager.getAddress("OVM_L1CrossDomainMessenger") == address(0), "Deploy: l1CrossDomainMessenger must be address(0) in addressManager");

        vm.broadcast(deployer);
        systemDictator.step2();

        require(addressManager.getAddress("OVM_L1CrossDomainMessenger") == address(0), "Deploy: addressManager l1CrossDomainMessengerProxy address is incorrect");

        SystemDictator.L2OutputOracleDynamicConfig memory l2OutputOracleDynamicConfig;
        l2OutputOracleDynamicConfig.l2OutputOracleStartingBlockNumber = deployConfig.l2OutputOracleStartingBlockNumber;
        l2OutputOracleDynamicConfig.l2OutputOracleStartingTimestamp = deployConfig.l2OutputOracleStartingTimestamp;

        bool optimismPortalDynamicConfig = true;

        vm.broadcast(deployer);
        systemDictator.updateDynamicConfig(
            l2OutputOracleDynamicConfig,
            optimismPortalDynamicConfig
        );

        vm.broadcast(deployer);
        systemDictator.step3();

        vm.broadcast(deployer);
        systemDictator.step4();
        require(addressManager.owner() == address(proxyAdmin), "Deploy: addressManager owner is incorrect");
        vm.prank(address(0));
        require(l1StandardBridgeProxy.getOwner() == address(proxyAdmin), "Deploy: l1StandardBridgeProxy owner is incorrect");
        vm.prank(address(0));
        require(l1ERC721BridgeProxy.admin() == address(proxyAdmin), "Deploy: l1ERC721BridgeProxy owner is incorrect");
        
        vm.broadcast(deployer);
        systemDictator.step5();

        require(L2OutputOracle(address(l2OutputOracleProxy)).latestBlockNumber() == deployConfig.l2OutputOracleStartingBlockNumber, "l2OutputOracleProxy l2StartingBlockNumber is incorrect");
        OptimismPortal testingOptimismPortal = OptimismPortal(payable(address(optimismPortalProxy)));
        require(testingOptimismPortal.l2Sender() == 0x000000000000000000000000000000000000dEaD, "Deploy: optimismPortalProxy l2Sender is incorrect");
        (uint128 prevBaseFee, uint64 prevBoughtGas, uint64 prevBlockNum) = testingOptimismPortal.params();
        require(prevBaseFee == 1 gwei, "Deploy: optimismPortalProxy prevBaseFee is incorrect");
        require(prevBoughtGas == 0, "Deploy: optimismPortalProxy prevBoughtGas is incorrect");
        require(prevBlockNum != 0, "Deploy: optimismPortalProxy prevBlockNum is incorrect");
        require(address(l1StandardBridgeProxy).balance == 0, "Deploy: l1StandardBridgeProxy balance is incorrect");
        require(address(L1StandardBridge(payable(address(l1StandardBridgeProxy))).messenger()) == address(l1CrossDomainMessengerProxy), "l1StandardBridgeProxy messenger is incorrect");
        require(OptimismMintableERC20Factory(address(optimismMintableERC20FactoryProxy)).BRIDGE() == address(l1StandardBridgeProxy), "optimismMintableERC20FactoryProxy l1StandardBridgeProxy is incorrect");
        require(address(L1ERC721Bridge(address(l1ERC721BridgeProxy)).messenger())== address(l1CrossDomainMessengerProxy), "l1ERC721BridgeProxy messenger is incorrect");

        vm.broadcast(deployer);
        systemDictator.finalize();
        require(proxyAdmin.owner() == deployConfig.finalSystemOwner, "Deploy: proxyAdmin finalSystemOwner is incorrect");
        require(systemDictator.finalized() == true, "Deploy: systemDictator is not finalized");
        console.log("Bedrock L1 Contract Deployment Complete");
    }
}
