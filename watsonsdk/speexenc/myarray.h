#if !defined ( _MYARRAY_H )
#define _MYARRAY_H

#include <assert.h>

template < class T >
class CMyArray
{
public:
	CMyArray( int iSize=1 );
	~CMyArray();

	int SetSize( int iSize );
	int GetSize()				{ return m_iSize; }
	T& operator[]( int iIdx )	{ return m_pBuffer[iIdx]; }
	T* GetBuffer()				{ return m_pBuffer; }
	void SetValue( T Value );

protected:
	T *m_pBuffer;
	int m_iSize;
};

template < class T >
inline CMyArray<T>::CMyArray( int iSize ) 
: m_pBuffer	( NULL )
, m_iSize	( 0 )
{
	SetSize( iSize );
}

template < class T >
inline CMyArray<T>::~CMyArray()
{
	if ( NULL != m_pBuffer ) {
		delete[] m_pBuffer;
		m_pBuffer = NULL;
	}
}

template < class T >
inline int CMyArray<T>::SetSize( int iSize )
{
	if ( iSize <= m_iSize ) {
		m_iSize = iSize;
		return m_iSize;
	}

	T *pTemp = new T[iSize];
	if ( NULL == pTemp ) 
		return m_iSize;
	
	if ( NULL != m_pBuffer) 
		delete[] m_pBuffer;
	m_pBuffer = pTemp;
	m_iSize = iSize;

	return m_iSize;		
}

template < class T >
inline void CMyArray<T>::SetValue( T Value )
{
	assert( m_pBuffer != NULL && m_iSize != 0 );

	for ( int i = 0; i < m_iSize; i++ )
		m_pBuffer[i] = Value;
}

#endif
