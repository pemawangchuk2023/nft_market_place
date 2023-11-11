import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import axios from 'axios';
import Web3Modal from 'web3modal';

import { Web3Storage } from 'web3.storage';
import { MarketAddress, MarketAddressABI } from './constants';

export const NFTContext = React.createContext();

const client = new Web3Storage({
  token: process.env.NEXT_PUBLIC_WEB_3_STORAGE_KEY,
});

const fetchContract = (signerOrProvider) =>
  new ethers.Contract(MarketAddress, MarketAddressABI, signerOrProvider);

export const NFTProvider = ({ children }) => {
  const [currentAccount, setCurrentAccount] = useState('');
  const nftCurrency = 'ETH';
  const [isLoadingNFT, setIsLoadingNFT] = useState(false);

  const checkIfWalletIsConnected = async () => {
    if (!window.ethereum) return alert('Please install MetaMask');

    const accounts = await window.ethereum.request({ method: 'eth_accounts' });

    if (accounts.length) {
      setCurrentAccount(accounts[0]);
    } else {
      console.log('No accounts found');
    }

    console.log({ accounts });
  };

  useEffect(() => {
    checkIfWalletIsConnected();
  }, []);

  const connectWallet = async () => {
    if (!window.ethereum) return alert('Please install MetaMask');
    const accounts = await window.ethereum.request({
      method: 'eth_requestAccounts',
    });

    setCurrentAccount(accounts[0]);
    window.location.reload();
  };

  const uploadToIPFS = async (files, setFileURL) => {
    const cid = await client.put(files);
    const url = `https://${cid}.ipfs.w3s.link/${files[0].name}`;
    console.log('stored files with cid:', cid);
    console.log(url);
    return url;
  };

  const createSale = async (url, formInputPrice, isReselling, id) => {
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();

    const price = ethers.utils.parseUnits(formInputPrice, 'ether');
    const contract = fetchContract(signer);
    const listingPrice = await contract.getListingPrice();

    const transaction = !isReselling
      ? await contract.createToken(url, price, {
          value: listingPrice.toString(),
        })
      : await contract.resellToken(id, price, {
          value: listingPrice.toString(),
        });

    setIsLoadingNFT(true);
    await transaction.wait();
  };

  const createNFT = async (formInput, fileURL, router, fileID) => {
    const { name, description, price } = formInput;

    if (!name || !description || !price || !fileURL) return;

    const data = new Blob(
      [JSON.stringify({ name, description, image: fileURL, fileID })],
      { type: 'application/json' }
    );

    const files = [new File([data], fileID)];
    try {
      const added = await client.put(files);
      // console.log('FILE ID: ', fileID);
      const url = `https://${added}.ipfs.w3s.link/${fileID}`;

      await createSale(url, price);
      router.push('/');
    } catch (e) {
      console.log('Error uploading file to IPFS', e);
    }
  };

  const fetchNFTs = async () => {
    setIsLoadingNFT(false);
    const provider = new ethers.providers.JsonRpcProvider(
      process.env.NEXT_PUBLIC_ALCHEMY_API_ENDPOINT
    );

    const contract = fetchContract(provider);

    const data = await contract.fetchMarketItems();

    const items = await Promise.all(
      data.map(async ({ tokenId, seller, owner, price: unformattedPrice }) => {
        const tokenURI = await contract.tokenURI(tokenId);
        const {
          data: { image, name, description },
        } = await axios.get(tokenURI);
        const price = ethers.utils.formatUnits(
          unformattedPrice.toString(),
          'ether'
        );

        return {
          price,
          tokenId: tokenId.toNumber(),
          seller,
          owner,
          image,
          name,
          description,
          tokenURI,
        };
      })
    );
    return items;
  };

  const fetchMyNFTsOrListedNFTs = async (type) => {
    setIsLoadingNFT(false);
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();

    const contract = fetchContract(signer);
    const data =
      type === 'fetchItemsListed'
        ? await contract.fetchItemsListed()
        : await contract.fetchMyNFTs();

    const items = await Promise.all(
      data.map(async ({ tokenId, seller, owner, price: unformattedPrice }) => {
        const tokenURI = await contract.tokenURI(tokenId);
        const {
          data: { image, name, description },
        } = await axios.get(tokenURI);
        const price = ethers.utils.formatUnits(
          unformattedPrice.toString(),
          'ether'
        );

        return {
          price,
          tokenId: tokenId.toNumber(),
          seller,
          owner,
          image,
          name,
          description,
          tokenURI,
        };
      })
    );
    return items;
  };

  const buyNft = async (nft) => {
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();

    const contract = fetchContract(signer);

    const price = ethers.utils.parseUnits(nft.price.toString(), 'ether');

    const transaction = await contract.createMarketSale(nft.tokenId, {
      value: price,
    });
    setIsLoadingNFT(true);
    await transaction.wait();
    setIsLoadingNFT(false);
  };
  return (
    <NFTContext.Provider
      value={{
        nftCurrency,
        connectWallet,
        currentAccount,
        uploadToIPFS,
        createNFT,
        fetchNFTs,
        fetchMyNFTsOrListedNFTs,
        buyNft,
        createSale,
        isLoadingNFT,
      }}
    >
      {children}
    </NFTContext.Provider>
  );
};
