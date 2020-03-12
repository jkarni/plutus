{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DeriveAnyClass             #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}
{-# OPTIONS_GHC -fno-ignore-interface-pragmas #-}
module Starter where
-- TRIM TO HERE
-- This is a starter contract, based on the Game contract,
-- containing the bare minimum required scaffolding.
--
-- What you should change to something more suitable for
-- your use case:
--   * The MyDatum type
--   * The MyMyRedeemerValue type
--
-- And add function implementations (and rename them to
-- something suitable) for the endpoints:
--   * publish
--   * redeem

import           Control.Monad              (void)
import qualified Language.PlutusTx          as PlutusTx
import           Language.PlutusTx.Prelude  hiding (Applicative (..))
import           Ledger                     (Address, PendingTx,
                                             scriptAddress)
import           Ledger.Value               (Value)
import           Playground.Contract
import           Language.Plutus.Contract
import qualified Ledger.Constraints as Constraints
import qualified Ledger.Typed.Scripts as Scripts

-- | These are the data script and redeemer types. We are using an integer
--   value for both, but you should define your own types.
newtype MyDatum = MyDatum Integer deriving newtype PlutusTx.IsData
PlutusTx.makeLift ''MyDatum

newtype MyRedeemer = MyRedeemer Integer deriving newtype PlutusTx.IsData
PlutusTx.makeLift ''MyRedeemer

-- | This method is the spending validator (which gets lifted to
--   its on-chain representation).
validateSpend :: MyDatum -> MyRedeemer -> PendingTx -> Bool
validateSpend _myDataValue _myRedeemerValue _ = error () -- Please provide an implementation.

-- | The address of the contract (the hash of its validator script).
contractAddress :: Address
contractAddress = Ledger.scriptAddress (Scripts.validatorScript starterInstance)

data Starter
instance Scripts.ScriptType Starter where
    type instance RedeemerType Starter = MyRedeemer
    type instance DatumType Starter = MyDatum

-- | The script instance is the compiled validator (ready to go onto the chain)
starterInstance :: Scripts.ScriptInstance Starter
starterInstance = Scripts.validator @Starter
    $$(PlutusTx.compile [|| validateSpend ||])
    $$(PlutusTx.compile [|| wrap ||]) where
        wrap = Scripts.wrapValidator @MyDatum @MyRedeemer

-- | The schema of the contract, with two endpoints.
type Schema =
    BlockchainActions
        .\/ Endpoint "publish" (Integer, Value)
        .\/ Endpoint "redeem" Integer

contract :: AsContractError e => Contract Schema e ()
contract = publish <|> redeem

-- | The "publish" contract endpoint.
publish :: AsContractError e => Contract Schema e ()
publish = do
    (i, lockedFunds) <- endpoint @"publish"
    let tx = Constraints.mustPayToTheScript (MyDatum i) lockedFunds
    void $ submitTxConstraints starterInstance tx

-- | The "redeem" contract endpoint.
redeem :: AsContractError e => Contract Schema e ()
redeem = do
    myRedeemerValue <- endpoint @"redeem"
    unspentOutputs <- utxoAt contractAddress
    let redeemer = MyRedeemer myRedeemerValue
        tx       = collectFromScript unspentOutputs redeemer
    void $ submitTxConstraintsSpending starterInstance unspentOutputs tx

endpoints :: AsContractError e => Contract Schema e ()
endpoints = contract

mkSchemaDefinitions ''Schema

$(mkKnownCurrencies [])
