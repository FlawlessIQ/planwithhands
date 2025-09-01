import Image from 'next/image'

export default function PhoneMockup({ src, alt, className = "" }) {
  return (
    <div className={`relative mx-auto ${className}`}>
      {/* iPhone frame */}
      <div className="relative bg-black rounded-[3rem] p-2 shadow-2xl max-w-sm mx-auto">
        {/* Screen bezel */}
        <div className="bg-black rounded-[2.5rem] p-1">
          {/* Notch */}
          <div className="absolute top-3 left-1/2 transform -translate-x-1/2 bg-black w-20 h-6 rounded-full z-10"></div>
          
          {/* Screen */}
          <div className="bg-white rounded-[2rem] overflow-hidden relative">
            <Image
              src={src}
              alt={alt}
              width={300}
              height={600}
              className="w-full h-auto"
              quality={90}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
