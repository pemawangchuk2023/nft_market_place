import { useEffect, useState, useContext } from 'react';
import { useRouter } from 'next/router';
import axios from 'axios';
import Image from 'next/image';

import { NFTContext } from '../context/NFTContext';
import { Button, Input, Loader } from '../components';

const ResellNFT = () => {
  const { createSale, isLoadingNFT } = useContext(NFTContext);
  const [price, setPrice] = useState('');
  const [image, setImage] = useState('');
  const router = useRouter();
  const { id, tokenURI } = router.query;
  const fetchNFT = async () => {
    if (!tokenURI) return;

    const { data } = await axios.get(tokenURI);

    setPrice(data.price);
    setImage(data.image);
  };

  useEffect(() => {
    fetchNFT();
  }, [id]);

  const resell = async () => {
    await createSale(tokenURI, price);

    router.push('/');
  };

  if (isLoadingNFT) {
    return (
      <div
        className='flexCenter min-h-screen'
        // style={{ height: '51vh' }}
      >
        <Loader />
      </div>
    );
  }

  return (
    <div className='flex justify-center sm:px-4 p-12'>
      <div className='w-3/5 md:w-full'>
        <h1 className='font-poppins dark:text-white text-nft-black-1 font-semibold text-2xl'>
          Resell NFT
        </h1>

        <Input
          inputType='number'
          title='Price'
          placeholder='Asset Price'
          handleClick={(e) => setPrice(e.target.value)}
        />

        {image && (
          <Image
            src={`/api/imageProxy?imageUrl=${encodeURIComponent(image)}`}
            width='350'
            height='350'
            className='rounded mt-4'
            layout='responsive'
          />
        )}

        <div className='mt-7 w-full flex justify-end'>
          <Button
            btnName='List NFT'
            btnType='primary'
            classStyles='rounded-xl'
            handleClick={resell}
          />
        </div>
      </div>
    </div>
  );
};

export default ResellNFT;
