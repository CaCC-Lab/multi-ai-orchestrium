import React from 'react';
import { FaStar, FaStarHalfAlt, FaRegStar } from 'react-icons/fa';

function ProductRating({ value, text, color }) {
  return (
    <div className="rating">
      <span>
        {value >= 1 ? (
          <FaStar color={color || '#f8e825'} />
        ) : value >= 0.5 ? (
          <FaStarHalfAlt color={color || '#f8e825'} />
        ) : (
          <FaRegStar color={color || '#f8e825'} />
        )}
      </span>
      <span>
        {value >= 2 ? (
          <FaStar color={color || '#f8e825'} />
        ) : value >= 1.5 ? (
          <FaStarHalfAlt color={color || '#f8e825'} />
        ) : (
          <FaRegStar color={color || '#f8e825'} />
        )}
      </span>
      <span>
        {value >= 3 ? (
          <FaStar color={color || '#f8e825'} />
        ) : value >= 2.5 ? (
          <FaStarHalfAlt color={color || '#f8e825'} />
        ) : (
          <FaRegStar color={color || '#f8e825'} />
        )}
      </span>
      <span>
        {value >= 4 ? (
          <FaStar color={color || '#f8e825'} />
        ) : value >= 3.5 ? (
          <FaStarHalfAlt color={color || '#f8e825'} />
        ) : (
          <FaRegStar color={color || '#f8e825'} />
        )}
      </span>
      <span>
        {value >= 5 ? (
          <FaStar color={color || '#f8e825'} />
        ) : value >= 4.5 ? (
          <FaStarHalfAlt color={color || '#f8e825'} />
        ) : (
          <FaRegStar color={color || '#f8e825'} />
        )}
      </span>
      <span className="ms-1">{text && text}</span>
    </div>
  );
}

export default ProductRating;